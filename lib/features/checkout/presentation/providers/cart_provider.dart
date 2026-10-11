import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:naavis_pos/features/checkout/domain/cart_item_model.dart';

import '../../data/cart_store.dart';

class CartNotifier extends Notifier<List<CartItem>> {
  /// true cuando la hidratación desde la base local terminó (o falló).
  bool _hydrated = false;

  @override
  List<CartItem> build() {
    _hydrated = false;
    // Hidratación asíncrona: el carrito guardado se restaura apenas abre la
    // app. Si el cajero agrega algo ANTES de que termine, se respeta lo que
    // haya en memoria (estado del usuario > caché).
    Future.microtask(_hydrate);
    return []; // Estado inicial vacío
  }

  Future<void> _hydrate() async {
    try {
      final items = await ref.read(cartStoreProvider).load();
      if (_hydrated) return;
      _hydrated = true;
      if (state.isEmpty && items.isNotEmpty) state = items;
    } catch (_) {
      // Sin base (tests, primera corrida rara): carrito normal en memoria.
      _hydrated = true;
    }
  }

  /// Guarda el carrito actual en la base local (best-effort).
  void _persist() {
    try {
      ref.read(cartStoreProvider).saveAll(state).catchError((_) {});
    } catch (_) {
      // Sin base disponible: el carrito sigue vivo en memoria.
    }
  }

  double get subtotal =>
      state.fold(0.0, (sum, item) => sum + item.total);

  void addProduct({
    required int variationId,
    required String name,
    required double price,
    required int maxStock,
  }) {
    // Variación agotada (o sin stock cargado): nunca entra al carrito.
    if (maxStock <= 0) return;

    final index = state.indexWhere((item) => item.variationId == variationId);

    if (index != -1) {
      final currentItem = state[index];
      if (currentItem.quantity < maxStock) {
        final updatedList = List<CartItem>.from(state);
        updatedList[index] = currentItem.copyWith(
          quantity: currentItem.quantity + 1,
        );
        state = updatedList;
        _persist();
      }
    } else {
      state = [
        ...state,
        CartItem(
          variationId: variationId,
          productName: name,
          price: price,
          quantity: 1,
          maxStock: maxStock,
        ),
      ];
      _persist();
    }
  }

  void updateQuantity(int variationId, int delta, {required int maxStock}) {
    final updatedList = <CartItem>[];

    for (final item in state) {
      if (item.variationId == variationId) {
        final newQuantity = item.quantity + delta;
        if (newQuantity > 0 && newQuantity <= maxStock) {
          updatedList.add(item.copyWith(quantity: newQuantity));
        } else if (newQuantity > 0 && newQuantity > maxStock) {
          updatedList.add(item.copyWith(quantity: maxStock));
        }
      } else {
        updatedList.add(item);
      }
    }

    state = updatedList;
    _persist();
  }

  void clear() {
    state = [];
    _persist();
  }
}

final cartProvider =
    NotifierProvider<CartNotifier, List<CartItem>>(CartNotifier.new);