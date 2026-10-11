import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Caché de imágenes del catálogo (disco + memoria), compartida por la
/// tarjeta del grid y el visor a pantalla completa.
///
/// - `maxNrOfCacheObjects: 500` (LRU): un catálogo chico entra completo y
///   lo que no se usa se recicla solo.
/// - `stalePeriod: 30 días`: respeta el `Cache-Control` que emite nginx
///   (ver README); las fotos se sirven desde disco sin volver a la red.
/// - La clave es la URL: Django agrega un sufijo aleatorio al subir un
///   archivo que ya existe, así que cada upload nueva tiene URL nueva y no
///   hace falta invalidar nada a mano.
///
/// En web esta caché no persiste (limitación del propio paquete): ahí el
/// almacenamiento lo aporta la caché HTTP del navegador con las cabeceras
/// de nginx.
class PosImageCacheManager {
  PosImageCacheManager._();

  static final BaseCacheManager instance = CacheManager(
    Config(
      'pos_product_images',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 500,
    ),
  );
}
