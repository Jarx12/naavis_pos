import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/outbox_repository.dart';
import '../../data/outbox_service.dart';
import '../widgets/order_conflict_dialog.dart';

/// Hoja con las órdenes de la cola local:
/// - "Requieren atención" (rechazadas por el server): editar o descartar.
/// - "Pendientes de envío" (sin conexión / reintentos): reintentar o
///   descartar.
///
/// También es la puerta de entrada manual por si el aviso automático del
/// conflicto se perdió (p.ej. el cajero cerró el diálogo).
class OutboxSheet extends ConsumerWidget {
  const OutboxSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.8,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: OutboxSheet(),
        ),
      ),
    );
  }

  Future<void> _confirmDiscard(
      BuildContext context, WidgetRef ref, OutboxRow row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar orden'),
        content: const Text(
            'La orden se eliminará de este equipo y NUNCA se enviará al '
            'server. ¿Continuar?'),
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
    if (confirmed == true) {
      await ref.read(outboxServiceProvider).discard(row.localId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(outboxRowsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Órdenes fuera de línea',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reintentar todo'),
              onPressed: () => ref.read(outboxServiceProvider).flush(),
            ),
          ],
        ),
        const Divider(),
        Expanded(
          child: rowsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Text('Error al leer la cola: $err',
                  style: const TextStyle(color: Colors.red)),
            ),
            data: (rows) => _buildList(context, ref, rows),
          ),
        ),
      ],
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, List<OutboxRow> rows) {
    if (rows.isEmpty) {
      return const Center(
        child: Text(
          'No hay órdenes pendientes.\nLas ventas offline se guardan aquí '
          'hasta poder enviarse.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final attention = rows.where((r) => r.needsAttention).toList();
    final pending = rows.where((r) => !r.needsAttention).toList();

    return ListView(
      children: [
        if (attention.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'REQUIEREN ATENCIÓN (no se enviarán solas)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ),
          for (final row in attention)
            _AttentionTile(
              row: row,
              onEdit: () {
                Navigator.pop(context);
                OrderConflictDialog.show(context, row.localId);
              },
              onDiscard: () => _confirmDiscard(context, ref, row),
            ),
        ],
        if (pending.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'PENDIENTES DE ENVÍO (se reintentan solas)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ),
          for (final row in pending)
            ListTile(
              dense: true,
              leading:
                  const Icon(Icons.hourglass_top, color: Colors.orange),
              title: Text(
                'Venta del '
                '${row.createdAt.day.toString().padLeft(2, '0')}/'
                '${row.createdAt.month.toString().padLeft(2, '0')} '
                '${row.createdAt.hour.toString().padLeft(2, '0')}:'
                '${row.createdAt.minute.toString().padLeft(2, '0')}',
              ),
              subtitle: Text(
                '${_itemCount(row)} artículos · ${row.attempts} intento(s)',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Reintentar ahora',
                    onPressed: () =>
                        ref.read(outboxServiceProvider).retryNow(row.localId),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 20, color: Colors.red),
                    tooltip: 'Descartar',
                    onPressed: () => _confirmDiscard(context, ref, row),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  static int _itemCount(OutboxRow row) {
    final items = row.payload['items'];
    if (items is! List) return 0;
    return items.fold<int>(0, (sum, item) {
      if (item is Map && item['quantity'] is int) {
        return sum + (item['quantity'] as int);
      }
      return sum;
    });
  }
}

class _AttentionTile extends StatelessWidget {
  final OutboxRow row;
  final VoidCallback onEdit;
  final VoidCallback onDiscard;

  const _AttentionTile({
    required this.row,
    required this.onEdit,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(
        row.isStockConflict ? Icons.inventory_2 : Icons.error_outline,
        color: Colors.red,
      ),
      title: Text(
        row.errorMessage ?? 'Orden rechazada por el server',
        style: const TextStyle(fontSize: 13),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        row.errorCode ?? '',
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(onPressed: onEdit, child: const Text('Editar')),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
            tooltip: 'Descartar',
            onPressed: onDiscard,
          ),
        ],
      ),
    );
  }
}
