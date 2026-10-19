class CreateOrderIn {
  final String customerName;
  final String deliveryType; // "PICKUP", "DELIVERY", "NACIONAL"
  final String paymentMethod; // "PAYPAL", "BINANCE", "PAGOMOVIL", "EFECTIVO_USD", "EFECTIVO_BS"
  final String? paymentRef;
  final String? couponCode;
  final double discountVolumen;
  final String? note;
  final List<OrderItemIn> items;
  // Pago mixto: ≥2 partes en USD que suman el total (misma forma que el
  // panel). Vacío = pedido de un solo método (payload de siempre).
  final List<PaymentSplit> pagos;

  CreateOrderIn({
    required this.customerName,
    required this.deliveryType,
    required this.paymentMethod,
    this.paymentRef,
    this.couponCode,
    this.discountVolumen = 0.0,
    this.note,
    required this.items,
    this.pagos = const [],
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
        if (pagos.isNotEmpty) 'pagos': pagos.map((e) => e.toJson()).toList(),
      };
}

/// Parte de un pago mixto: `{"metodo": ..., "monto": ...}` en dólares.
class PaymentSplit {
  final String method;
  final double amount;

  PaymentSplit({required this.method, required this.amount});

  Map<String, dynamic> toJson() => {'metodo': method, 'monto': amount};
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