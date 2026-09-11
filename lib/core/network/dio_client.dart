import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/domain/auth_model.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../config/app_config.dart';

class DioClient {
  final Dio dio;

  DioClient(Ref ref)
      : dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            headers: {'Content-Type': 'application/json'},
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = ref.read(authTokenProvider);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          // Si expira el access token (401)
          if (error.response?.statusCode == 401) {
            final authState = ref.read(authProvider);
            final refreshToken = authState.tokens?.refresh;

            if (refreshToken != null && refreshToken.isNotEmpty) {
              try {
                // Instancia limpia para la petición del refresh
                final refreshDio = Dio(
                  BaseOptions(baseUrl: dio.options.baseUrl),
                );

                final response = await refreshDio.post(
                  '/token/refresh',
                  data: {'refresh': refreshToken},
                );

                final newAccess = response.data['access'];
                // Si el backend también devuelve un nuevo refresh token, lo usamos; si no, mantenemos el actual
                final newRefresh = response.data['refresh'] ?? refreshToken;

                final newTokens = AuthTokens(
                  access: newAccess,
                  refresh: newRefresh,
                );

                // Guardar y actualizar en el Provider
                await ref.read(authProvider.notifier).updateTokens(newTokens);

                // Reintentar la petición original con el nuevo token
                error.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
                final clonedResponse = await dio.fetch(error.requestOptions);
                return handler.resolve(clonedResponse);
              } catch (_) {
                // Si el refresh token venció (pasaron los 7 días), forzar logout
                await ref.read(authProvider.notifier).logout();
              }
            } else {
              await ref.read(authProvider.notifier).logout();
            }
          }
          return handler.next(error);
        },
      ),
    );
  }
}