import 'package:dio/dio.dart';

import 'sync_models.dart';

/// Cliente HTTP del delta del catálogo (`GET /sync/catalog`).
///
/// Sin `since` el server devuelve el catálogo completo (seed); con `since`
/// devuelve solo lo tocado desde ese cursor más las tumbas (`deleted_*`).
/// `offset` pagina las tres colecciones a la vez: mientras `has_more` sea
/// true, repetir con `offset += limit` y acumular.
class SyncRepository {
  final Dio _dio;

  SyncRepository(this._dio);

  /// Mismo `limit` que se envía al server: el `offset` del drain debe
  /// avanzar exactamente este tamaño para que las páginas no se solapen
  /// ni se salten filas.
  static const int pageSize = 500;

  Future<SyncPage> fetchPage({String? since, int offset = 0}) async {
    final response = await _dio.get(
      '/sync/catalog',
      queryParameters: {
        if (since != null && since.isNotEmpty) 'since': since,
        'limit': pageSize,
        'offset': offset,
      },
    );
    return SyncPage.fromJson(response.data as Map<String, dynamic>);
  }
}
