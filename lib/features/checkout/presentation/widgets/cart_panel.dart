import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/cart_provider.dart';

class CartPanel extends ConsumerWidget {
  final double? currentRate;
  final VoidCallback onCheckout;

  const CartPanel({
    super.key,
    required this.currentRate,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);

    return SafeArea(
      // El botón "PROCESAR COBRO" va al final de la columna, justo contra el
      // borde inferior. Sin esto queda debajo de la barra de navegación de
      // Android: el `CartPanel` se usa tanto en el panel lateral (tablet) como
      // dentro de un `showModalBottomSheet` (móvil), y en ambos casos el
      // contenedor no protege el borde inferior.
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Orden Actual',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              if (cartItems.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep, size: 22),
                  tooltip: 'Vaciar carrito',
                  onPressed: cartNotifier.clear,
                ),
            ],
          ),
          const Divider(height: 1),

          // ── Items ──────────────────────────────────────────────
          Expanded(
            child: cartItems.isEmpty
                ? const Center(
                    child: Text(
                      'El carrito está vacío',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: cartItems.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      final double priceUsd = (item.price as num).toDouble();
                      final double subtotalUsd = priceUsd * item.quantity;
                      final double? subtotalBs = currentRate != null
                          ? subtotalUsd * currentRate!
                          : null;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '\$${priceUsd.toStringAsFixed(2)} c/u',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '\$${subtotalUsd.toStringAsFixed(2)}'
                                    '${subtotalBs != null ? '  ·  Bs. ${subtotalBs.toStringAsFixed(2)}' : ''}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Qty controls
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        size: 22,
                                      ),
                                      onPressed: () =>
                                          cartNotifier.updateQuantity(
                                            item.variationId,
                                            -1,
                                            maxStock: item.maxStock,
                                          ),
                                    ),
                                    SizedBox(
                                      width: 28,
                                      child: Text(
                                        '${item.quantity}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                        size: 22,
                                      ),
                                      onPressed: () =>
                                          cartNotifier.updateQuantity(
                                            item.variationId,
                                            1,
                                            maxStock: item.maxStock,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          const Divider(height: 1),

          // ── Totals ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: _buildTotalSection(
              subtotal: cartNotifier.subtotal,
              rate: currentRate,
            ),
          ),

          // ── Checkout ───────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: cartItems.isEmpty ? Colors.grey : Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.point_of_sale),
              label: const Text(
                'PROCESAR COBRO',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: cartItems.isEmpty ? null : onCheckout,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSection({required double subtotal, required double? rate}) {
    final double? totalBs = rate != null ? subtotal * rate : null;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Text(
                'TOTAL USD:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '\$${subtotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Text(
                'TOTAL BS. (Ref):',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                totalBs != null
                    ? 'Bs. ${totalBs.toStringAsFixed(2)}'
                    : 'Bs. --',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (rate != null) ...[
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Tasa: ${rate.toStringAsFixed(2)} Bs./USD',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ),
        ],
      ],
    );
  }
}
