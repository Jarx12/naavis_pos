import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../config/app_config.dart';
import 'pos_image_cache.dart';

/// Precachéa en disco las fotos del catálogo mientras corre la sync, para
/// que la primera vez que el cajero ve un producto la imagen ya esté local
/// (hasta ahora solo se cacheaban al renderizarse en el grid/visor).
///
/// - Usa la MISMA caché que [CatalogImage] (`PosImageCacheManager`), así el
///   precache y el acceso desde la UI comparten el LRU de 500 archivos y la
///   revalidación a 30 días.
/// - Es mejor esfuerzo en segundo plano: un fallo individual (404, red a
///   medias) se ignora y la imagen se descarga igual al mostrarse con
///   `CachedNetworkImage`, igual que antes.
/// - En web no hace nada: `flutter_cache_manager` no persiste ahí (limitación
///   documentada del paquete) y la caché la aporta el navegador.
class CatalogImagePrefetcher {
  CatalogImagePrefetcher({this._cacheManager});

  /// Resuelto en cada uso (no en el constructor) para que un subclase de
  /// test que sobrescriba [prefetch] nunca construya el gestor real, que
  /// toca canales de plataforma al abrir su base.
  final BaseCacheManager? _cacheManager;

  /// Descargas simultáneas: suficiente para llenar la caché rápido sin
  /// saturar el enlace ni al servidor (nginx sirve `/media/` estático).
  static const int _concurrency = 4;

  /// Lleva una URL del payload de sync —relativa (`/media/…`) o absoluta—
  /// a la forma en que la resuelve la UI (ver `pos_screen.dart`): el
  /// ORIGIN del `baseUrl` de la API, sin el prefijo `/api/v1`. Las URLs
  /// absolutas se devuelven tal cual.
  static String absoluteImageUrl(
    String url, {
    String baseUrl = AppConfig.baseUrl,
  }) {
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    final uri = Uri.parse(baseUrl);
    final origin =
        '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    return '$origin$url';
  }

  /// Deduplica [urls] y las normaliza a absolutas con [absoluteImageUrl],
  /// descartando las vacías. Expuesta para tests.
  List<String> normalize(Iterable<String> urls) => <String>{
        for (final url in urls)
          if (url.isNotEmpty) absoluteImageUrl(url),
      }.toList();

  /// Descarga [urls] a la caché de disco. Cada descarga usa
  /// `downloadFile`, que si el archivo ya está cacheado y vigente responde
  /// desde disco sin tocar la red. Los errores por URL se ignoran (mejor
  /// esfuerzo).
  Future<void> prefetch(Iterable<String> urls) async {
    if (kIsWeb) return; // en web no hay caché de disco (ver README)
    final cache = _cacheManager ?? PosImageCacheManager.instance;
    final pending = normalize(urls);

    // Workers tomando de una cola indexada: `index++` es síncrono, así que
    // no hay carrera entre workers en el modelo single-thread de Dart.
    var index = 0;
    Future<void> worker() async {
      while (true) {
        final i = index++;
        if (i >= pending.length) return;
        try {
          await cache.downloadFile(pending[i]);
        } catch (_) {
          // Mejor esfuerzo: la foto se recuperará al mostrarse en la UI.
        }
      }
    }

    await Future.wait([for (var i = 0; i < _concurrency; i++) worker()]);
  }
}
