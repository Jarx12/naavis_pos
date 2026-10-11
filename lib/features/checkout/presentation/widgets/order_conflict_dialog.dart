import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../catalog/data/local_catalog_repository.dart';
import '../../data/outbox_repository.dart';
import '../../data/outbox_service.dart';

/// Ítem editable del diálogo de conflicto.
class _EditableItem {
  final int variationId;
  String label;
  int quantity;
  int bound; // máximo permitido (available del server o stock local)
  String boundNote;

  _EditableItem({
    required this.variationId,
    required this.label,
    required this.quantity,
    required this.bound,
    required this.boundNote,
  });
}

/// Diálogo de resolución cuando el server rechaza una orden por negocio
/// (típicamente `INSUFFICIENT_STOCK`): el cajero decide
/// EDITAR la orden (cantidades acotadas al stock real / quitar el cupón)
/// o DESCARTARLA. La orden nunca se reenvía sola.
class OrderConflictDialog extends ConsumerStatefulWidget {
  final int localId;

  const OrderConflictDialog({super.key, required this.localId});

  static Future<void> show(BuildContext context, int localId) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => OrderConflictDialog(localId: localId),
    );
  }

  @override
  ConsumerState<OrderConflictDialog> createState() =>
      _OrderConflictDialogState();
}

class _OrderConflictDialogState extends ConsumerState<OrderConflictDialog> {
  List<_EditableItem> _items = [];
  OutboxRow? _row;
  bool _includeCoupon = false;
  String? _originalCoupon;
  bool _loading = true;
  bool _saving = false;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final outbox = ref.read(outboxServiceProvider);
    final row = await outbox.getRow(widget.localId);
    if (!mounted) return;
    if (row == null) {
      // La fila desapareció (enviada/descartada en paralelo).
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      return;
    }

    final details = row.errorDetails;
    final conflictId =
        details?['variation_id'] is int ? details!['variation_id'] as int : null;

    final local = ref.read(localCatalogProvider);
    final items = <_EditableItem>[];
    for (final raw in (row.payload['items'] as List<dynamic>? ?? const [])) {
      if (raw is! Map) continue;
      final vid = raw['variation_id'];
      final qty = raw['quantity'];
      if (vid is! int || qty is! int) continue;

      String label = 'Variación #$vid';
      int bound = qty;
      String boundNote = 'stock no verificado';

      if (conflictId == vid && details != null) {
        // El server dijo exactamente cuánto hay: es la fuente autoritativa
        // del último intento.
        label = '${details['product'] ?? ''} (${details['variation_type'] ?? ''})'
            .trim();
        bound = details['available'] is int ? details['available'] as int : 0;
        boundNote = 'disponible según el server';
      } else {
        final info = await local.getVariationInfo(vid);
        if (info != null) {
          label = info.label;
          bound = info.stock;
          boundNote = 'stock en este equipo';
        }
      }

      items.add(_EditableItem(
        variationId: vid,
        label: label,
        // Si pide más de lo disponible, la cantidad arranca acotada.
        quantity: qty > bound ? bound : qty,
        bound: bound,
        boundNote: boundNote,
      ));
    }

    setState(() {
      _row = row;
      _items = items;
      _originalCoupon = row.payload['coupon_code']?.toString();
      _includeCoupon = (_originalCoupon ?? '').isNotEmpty;
      _localError = null;
      _loading = false;
    });
  }

  bool get _canRetry => !_saving && _items.any((item) => item.quantity > 0);

  Map<String, dynamic> _buildPayload() {
    final payload = Map<String, dynamic>.from(_row!.payload);
    payload['items'] = [
      for (final item in _items)
        if (item.quantity > 0)
          {'variation_id': item.variationId, 'quantity': item.quantity},
    ];
    payload['coupon_code'] =
        _includeCoupon && (_originalCoupon ?? '').isNotEmpty
            ? _originalCoupon
            : null;
    return payload;
  }

  Future<void> _retry() async {
    setState(() {
      _saving = true;
      _localError = null;
    });
    final result = await ref
        .read(outboxServiceProvider)
        .saveEditAndRetry(widget.localId, _buildPayload());
    if (!mounted) return;

    switch (result.outcome) {
      case OutboxOutcome.sent:
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(SnackBar(
          content: Text(
              '¡Orden #${result.orderId} creada! Total: Bs. ${result.totalBs ?? ''}'),
          backgroundColor: Colors.green,
        ));
      case OutboxOutcome.waiting:
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(const SnackBar(
          content: Text('Sin conexión: la orden se enviará sola al reconectar.'),
          backgroundColor: Colors.orange,
        ));
      case OutboxOutcome.attention:
        // Sigue rechazada: se queda el diálogo para seguir editando.
        setState(() {
          _saving = false;
          _localError =
              result.errorMessage ?? 'El server volvió a rechazar la orden.';
        });
        _load();
    }
  }

  Future<void> _discard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar orden'),
        content: const Text(
            'La orden se eliminará de este equipo y NUNCA se enviará al '
            'server. Los artículos no vuelven al carrito.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref.read(outboxServiceProvider).discard(widget.localId);
    if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AlertDialog(
        content: SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final row = _row;
    if (row == null) return const SizedBox.shrink();

    return AlertDialog(
      title: Text(row.isStockConflict
          ? 'Sin stock suficiente'
          : 'Orden rechazada por el server'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row.errorMessage ??
                  'El server rechazó la orden. Edítala o descártala.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              'Esta orden NO se enviará hasta que la edites o la descartes.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            for (final item in _items) _buildItemTile(item),
            if (_originalCoupon != null && _originalCoupon!.isNotEmpty) ...[
              const Divider(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text('Cupón: $_originalCoupon'),
                subtitle: const Text('Quítalo si el rechazo fue por cupón'),
                value: _includeCoupon,
                onChanged: (v) => setState(() => _includeCoupon = v),
              ),
            ],
            if (_localError != null) ...[
              const SizedBox(height: 8),
              Text(
                _localError!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : _discard,
          child: const Text('Descartar', style: TextStyle(color: Colors.red)),
        ),
        ElevatedButton(
          onPressed: _canRetry ? _retry : null,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Guardar y reenviar',
                  style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildItemTile(_EditableItem item) {
    final soldOut = item.bound < 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(
                  soldOut
                      ? 'Agotado: quítalo de la orden'
                      : 'Máx. ${item.bound} (${item.boundNote})',
                  style: TextStyle(
                    fontSize: 11,
                    color: soldOut ? Colors.red : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          if (!soldOut) ...[
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              onPressed: item.quantity > 0
                  ? () => setState(() => item.quantity--)
                  : null,
            ),
            Text('${item.quantity}',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold)),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add_circle_outline, size: 20),
              onPressed: item.quantity < item.bound
                  ? () => setState(() => item.quantity++)
                  : null,
            ),
          ] else
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: Colors.red),
              tooltip: 'Quitar de la orden',
              onPressed: () => setState(() => item.quantity = 0),
            ),
          if (soldOut && item.quantity == 0)
            const Icon(Icons.check, size: 16, color: Colors.green),
        ],
      ),
    );
  }
}
