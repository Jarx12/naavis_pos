import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

// Modelo para la respuesta de /payments/config (comisiones del backend).
class PaymentsConfig {
  final double paypalCommissionPct;
  final double paypalCommissionFixed;

  const PaymentsConfig({
    required this.paypalCommissionPct,
    required this.paypalCommissionFixed,
  });

  factory PaymentsConfig.fromJson(Map<String, dynamic> json) {
    return PaymentsConfig(
      paypalCommissionPct: (json['paypal_comision_pct'] as num).toDouble(),
      paypalCommissionFixed: (json['paypal_comision_fija'] as num).toDouble(),
    );
  }

  /// Lo que el cliente debe enviar por PayPal para que al negocio le queden
  /// exactamente [amount] después de la comisión (% + fija). Mismo cálculo
  /// que el panel: (monto + fija) / (1 − pct/100).
  double paypalGross(double amount) {
    final fraction = paypalCommissionPct / 100;
    if (amount <= 0 || fraction <= 0 || fraction >= 1) return amount;
    return (amount + paypalCommissionFixed) / (1 - fraction);
  }
}

/// Comisiones de pago: se consultan al abrir el checkout y viven en memoria.
/// Si el server falla, la UI simplemente omite la línea de comisión (es
/// informativa, no bloquea la venta).
class PaymentsConfigNotifier extends AsyncNotifier<PaymentsConfig> {
  @override
  Future<PaymentsConfig> build() async {
    final dioClient = ref.read(dioClientProvider);
    final response = await dioClient.dio.get('/payments/config');
    return PaymentsConfig.fromJson(response.data as Map<String, dynamic>);
  }
}

final paymentsConfigProvider =
    AsyncNotifierProvider<PaymentsConfigNotifier, PaymentsConfig>(
        PaymentsConfigNotifier.new);