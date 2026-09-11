class CouponValidationResult {
  final bool valid;
  final String message;
  final double discountAmount;

  CouponValidationResult({
    required this.valid,
    required this.message,
    required this.discountAmount,
  });

  factory CouponValidationResult.fromJson(Map<String, dynamic> json) {
    return CouponValidationResult(
      valid: json['valid'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}