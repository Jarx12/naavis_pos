import 'package:dio/dio.dart';
import '../domain/auth_model.dart';

class AuthRepository {
  final Dio _dio;

  AuthRepository(this._dio);

  Future<AuthTokens> login(String username, String password) async {
    try {
      final response = await _dio.post(
        '/token/pair',
        data: {
          'username': username,
          'password': password,
        },
      );

      return AuthTokens.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_friendlyErrorMessage(e));
    } catch (_) {
      throw Exception(
        'No se pudo completar el inicio de sesión. Inténtalo de nuevo.',
      );
    }
  }

  /// Convierte un [DioException] en un mensaje entendible para el usuario,
  /// en lugar de mostrar el código/texto crudo del backend.
  String _friendlyErrorMessage(DioException e) {
    final statusCode = e.response?.statusCode;

    // El endpoint de token responde 400/401/403 cuando la combinación
    // usuario/contraseña no existe o no es válida.
    if (statusCode == 400 || statusCode == 401 || statusCode == 403) {
      return 'No se encuentra dicha combinación de usuario y contraseña.';
    }

    // Sin internet, DNS caído o servidor sin respuesta.
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'No se pudo conectar con el servidor. Revisa tu conexión a internet.';
    }

    // Cualquier otro caso: se intenta usar el detalle del backend solo si
    // es un texto legible.
    final detail = _readableDetail(e.response?.data);
    if (detail != null) return detail;

    return 'Ocurrió un error inesperado. Inténtalo de nuevo.';
  }

  /// Extrae un mensaje legible del cuerpo de la respuesta.
  ///
  /// El cuerpo puede ser un Map (`detail`), un String plano, o una lista
  /// (errores de validación 422 de FastAPI). Se ignoran los mapas crudos para
  /// no mostrar algo como `{'detail': ...}` al usuario.
  String? _readableDetail(dynamic data) {
    if (data is Map) {
      final detail = data['detail'] ?? data['message'];

      if (detail is String && detail.trim().isNotEmpty) return detail.trim();

      // FastAPI 422: `detail` es una lista de errores.
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map) {
          final msg = first['msg'];
          if (msg is String && msg.trim().isNotEmpty) return msg.trim();
        }
      }
    }

    if (data is String && data.trim().isNotEmpty) return data.trim();

    return null;
  }
}