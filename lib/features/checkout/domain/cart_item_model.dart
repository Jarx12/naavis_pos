class CartItem {
  final int variationId;
  final String productName;
  final double price;
  final int quantity;
  final int maxStock;

  CartItem({
    required this.variationId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.maxStock,
  });

  // Getter para calcular el total por item
  double get total => price * quantity;

  CartItem copyWith({
    int? variationId,
    String? productName,
    double? price,
    int? quantity,
    int? maxStock,
  }) {
    return CartItem(
      variationId: variationId ?? this.variationId,
      productName: productName ?? this.productName,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      maxStock: maxStock ?? this.maxStock,
    );
  }
}