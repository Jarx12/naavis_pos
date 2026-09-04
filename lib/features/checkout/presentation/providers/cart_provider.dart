import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:naavis_pos/features/checkout/domain/cart_item_model.dart';

class CartNotifier extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() {
    return []; // Estado inicial vacio
  }

  double get subtotal =>
      state.fold(0.0, (sum, item) => sum + item.total);

  void addProduct({
    required int variationId,
    required String name,
    required double price,
    required int maxStock,
  }) {
    final index = state.indexWhere((item) => item.variationId == variationId);

    if (index != -1) {
      final currentItem = state[index];
      if (currentItem.quantity < maxStock) {
        final updatedList = List<CartItem>.from(state);
        updatedList[index] = currentItem.copyWith(
          quantity: currentItem.quantity + 1,
        );
        state = updatedList;
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
  }

  void clear() {
    state = [];
  }
}

final cartProvider =
    NotifierProvider<CartNotifier, List<CartItem>>(CartNotifier.new);