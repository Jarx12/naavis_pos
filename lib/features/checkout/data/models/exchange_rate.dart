import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// Modelo para la respuesta de /exchange-rate/current
class ExchangeRate {
  final String currency;
  final double rate;
  final DateTime updatedAt;

  ExchangeRate({
    required this.currency,
    required this.rate,
    required this.updatedAt,
  });

  factory ExchangeRate.fromJson(Map<String, dynamic> json) {
    return ExchangeRate(
      currency: json['currency'] ?? 'USD_VES',
      rate: (json['rate'] as num).toDouble(),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

// FutureProvider para obtener la tasa del backend
final currentExchangeRateProvider = FutureProvider<ExchangeRate>((ref) async {
  final dioClient = ref.watch(dioClientProvider);
  final response = await dioClient.dio.get('/exchange-rate/current');
  return ExchangeRate.fromJson(response.data as Map<String, dynamic>);
});