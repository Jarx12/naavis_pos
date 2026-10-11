import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'pos_image_cache.dart';

/// Imagen del catálogo con la estrategia de caché correcta por plataforma:
///
/// - **Nativo**: [CachedNetworkImage] con caché en disco
///   ([PosImageCacheManager], LRU + revalidación cada 30 días).
/// - **Web**: [Image.network] a secas. En web `cached_network_image` no
///   cachea (limitación documentada por el propio paquete: su gestor usa
///   almacenamiento en memoria que nunca persiste) y su cadena de decodificación
///   no maneja errores, lo que dejaba el placeholder clavado sobre el fondo
///   oscuro del visor ("pantalla negra") al volver a una foto ya vista.
///   La caché en web la aporta el navegador con las cabeceras de nginx
///   (`Cache-Control` del bloque `/media/`, ver README) + el `ImageCache`
///   de Flutter para los swipes del carrusel.
///
/// [useDiskCache] solo existe para tests: con `false` se fuerza la rama de
/// red también en nativo (el FakeAsync de los widget tests nunca completa
/// el I/O del gestor en disco).
class CatalogImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final int? memCacheWidth;
  final Widget Function(BuildContext context, String url) placeholder;
  final Widget Function(BuildContext context, String url, Object error)
      errorWidget;

  const CatalogImage({
    super.key,
    required this.imageUrl,
    required this.fit,
    this.memCacheWidth,
    required this.placeholder,
    required this.errorWidget,
  });

  /// Solo tests: desactiva el gestor con disco (ver doc de la clase).
  static bool useDiskCache = true;

  @override
  Widget build(BuildContext context) {
    final cacheToDisk = !kIsWeb && useDiskCache;
    if (cacheToDisk) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: fit,
        cacheManager: PosImageCacheManager.instance,
        memCacheWidth: memCacheWidth,
        placeholder: placeholder,
        errorWidget: errorWidget,
      );
    }
    return Image.network(
      imageUrl,
      fit: fit,
      cacheWidth: memCacheWidth,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : placeholder(context, imageUrl),
      errorBuilder: (context, error, stackTrace) =>
          errorWidget(context, imageUrl, error),
    );
  }
}
