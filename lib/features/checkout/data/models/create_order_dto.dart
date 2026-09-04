class CreateOrderIn {
  final String customerName;
  final String deliveryType; // "PICKUP", "DELIVERY", "NACIONAL"
  final String paymentMethod; // "PAYPAL", "BINANCE", "PAGOMOVIL", "EFECTIVO_USD", "EFECTIVO_BS"
  final String? paymentRef;
  final String? couponCode;
  final double discountVolumen;
  final String? note;
  final List<OrderItemIn> items;

  CreateOrderIn({
    required this.customerName,
    required this.deliveryType,
    required this.paymentMethod,
    this.paymentRef,
    this.couponCode,
    this.discountVolumen = 0.0,
    this.note,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
        'customer_name': customerName,
        'delivery_type': deliveryType,
        'payment_method': paymentMethod,
        'payment_ref': (paymentRef != null && paymentRef!.trim().isNotEmpty) ? paymentRef : null,
        'coupon_code': (couponCode != null && couponCode!.trim().isNotEmpty) ? couponCode : null,
        'discount_volumen': discountVolumen,
        'note': (note != null && note!.trim().isNotEmpty) ? note : null,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class OrderItemIn {
  final int variationId;
  final int quantity;

  OrderItemIn({required this.variationId, required this.quantity});

  Map<String, dynamic> toJson() => {
        'variation_id': variationId,
        'quantity': quantity,
      };
}