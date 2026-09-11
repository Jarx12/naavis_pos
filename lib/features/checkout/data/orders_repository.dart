import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../domain/coupon_validation_result.dart';

class OrdersRepository {
  final Dio dio;

  OrdersRepository(this.dio);

  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> orderPayload) async {
    try {
      final response = await dio.post('/orders', data: orderPayload);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response != null && e.response?.data is Map) {
        final errorData = e.response?.data as Map<String, dynamic>;

        if (errorData.containsKey('detail')) {
          final detail = errorData['detail'];
          if (detail is List) {
            final firstError = detail.first['msg'] ?? 'Error de validación';
            throw Exception(firstError);
          }
          throw Exception(detail.toString());
        }
      }
      throw Exception('Error al conectar con el servidor: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado: $e');
    }
  }

  Future<CouponValidationResult> validateCoupon({
    required String code,
    required double cartTotal,
  }) async {
    try {
      final response = await dio.post(
        '/coupons/validate',
        data: {
          'code': code,
          'cart_total': cartTotal,
        },
      );
      return CouponValidationResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response != null && e.response?.data is Map) {
        final errorData = e.response?.data as Map<String, dynamic>;
        if (errorData.containsKey('detail')) {
          throw Exception(errorData['detail'].toString());
        }
      }
      throw Exception('Error al validar el cupón: ${e.message}');
    }
  }
}

// Declaración del provider para ser consumido en la app
final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return OrdersRepository(dioClient.dio);
});