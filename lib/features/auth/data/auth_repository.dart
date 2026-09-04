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

      final errorMessage = e.response?.data['detail'] ??
          e.response?.data['message'] ??
          'Error Dio (${e.type}): ${e.message ?? e.error}';
      
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Ocurrió un error inesperado: $e');
    }
  }
}