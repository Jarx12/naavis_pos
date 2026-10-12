import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/images/catalog_image_prefetcher.dart';
import '../../catalog/data/local_catalog_repository.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import 'sync_repository.dart';

/// Resultado de una corrida de sync.
class SyncResult {
  final bool ok;
  final bool offline;
  final bool changed;
  final String? message;

  const SyncResult._({
    required this.ok,
    this.offline = false,
    this.changed = false,
    this.message,
  });

  const SyncResult.success({required bool changed})
      : this._(ok: true, changed: changed);

  const SyncResult.offline() : this._(ok: false, offline: true);

  const SyncResult.error(String message) : this._(ok: false, message: message);
}

/// Orquesta seed + delta contra `GET /sync/catalog`.
///
/// - Sin cursor local: seed completo (drain de páginas con `has_more`).
/// - Con cursor: delta desde la `server_time` guardada.
/// - El cursor que se persiste es el `server_time` de la PRIMERA página del
///   drain: el server lo toma antes de consultar, así ningún cambio
///   concurrente se pierde; re-fetchear filas del límite es inocuo (upserts
///   idempotentes).
/// - Las corridas se serializan: si llega otra sync mientras hay una en
///   vuelo, se adhiere a la misma en vez de abrirla en paralelo.
/// - Tras una sync exitosa se precachéan en segundo plano las fotos del
///   catálogo ([CatalogImagePrefetcher]), sin bloquear el resultado.
class SyncService {
  final SyncRepository _remote;
  final LocalCatalogRepository _local;
  final CatalogImagePrefetcher? _imagePrefetcher;

  SyncService(
    this._remote,
    this._local, {
    this._imagePrefetcher,
  });

  Future<SyncResult>? _inflight;

  Future<SyncResult> sync() => _inflight ??= _run().whenComplete(() {
        _inflight = null;
      });

  Future<SyncResult> _run() async {
    try {
      final cursor = await _local.readSyncState();
      // `newCursor` conserva el `server_time` de la PRIMERA página del
      // drain (se toma antes de consultar en el server).
      var newCursor = '';
      var offset = 0;
      var changed = false;

      while (true) {
        final page = await _remote.fetchPage(
          since: cursor.seeded ? cursor.serverTime : null,
          offset: offset,
        );
        if (newCursor.isEmpty) newCursor = page.serverTime;
        changed = await _local.applyPage(page) || changed;
        if (!page.hasMore) break;
        offset += SyncRepository.pageSize;
        if (offset > 100000) break; // red de seguridad, nunca debe pasar
      }

      if (newCursor.isNotEmpty) {
        await _local.saveCursor(newCursor);
      }
      // Precachear en disco las fotos del catálogo, en segundo plano y a
      // mayor esfuerzo: no bloquea el resultado de la sync ni la UI, y si
      // algo falla (o la app se cierra a mitad de camino) la foto se
      // descarga igual al mostrarse con CachedNetworkImage.
      _scheduleImagePrefetch();
      return SyncResult.success(changed: changed);
    } on DioException catch (e) {
      // Sin respuesta HTTP = sin conexión (timeout de conexión, socket…).
      if (e.response == null) return const SyncResult.offline();
      return SyncResult.error(_serverMessage(e));
    } catch (e) {
      return SyncResult.error('Error inesperado al sincronizar: $e');
    }
  }

  /// Lee las URLs de las fotos del catálogo local y las manda a la caché
  /// de disco SIN esperarlas. Se lee desde la DB (no solo desde las
  /// páginas de esta corrida) para retomar un precache interrumpido
  /// aunque el delta no traiga cambios de contenido; lo que ya esté
  /// cacheado y vigente el gestor lo responde desde disco sin red.
  void _scheduleImagePrefetch() {
    final prefetcher = _imagePrefetcher;
    if (prefetcher == null) return;
    unawaited(() async {
      try {
        final urls = await _local.getImageUrls();
        if (urls.isNotEmpty) await prefetcher.prefetch(urls);
      } catch (_) {
        // Mejor esfuerzo: nunca debe hacer fallar la sync ni la UI.
      }
    }());
  }

  static String _serverMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }
    return 'Error del servidor al sincronizar (${e.response?.statusCode}).';
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  final dio = ref.watch(dioClientProvider).dio;
  return SyncService(
    SyncRepository(dio),
    ref.watch(localCatalogProvider),
    imagePrefetcher: CatalogImagePrefetcher(),
  );
});
