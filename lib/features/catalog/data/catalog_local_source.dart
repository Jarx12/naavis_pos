import '../../sync/data/sync_models.dart';
import '../domain/category_model.dart';
import '../domain/product_model.dart';

/// Estado de sincronización guardado (cursor).
class SyncCursor {
  /// `server_time` crudo de la primera página del último delta aplicado.
  final String? serverTime;

  /// true cuando ya existe al menos un seed/delta completo aplicado.
  final bool seeded;

  const SyncCursor({this.serverTime, this.seeded = false});
}

/// Acceso a la caché local del catálogo.
///
/// Hay dos implementaciones:
/// - [LocalCatalogRepository] (Drift): nativo y web con navegador capaz de
///   compilar `sqlite3.wasm` — persiste entre sesiones y soporta delta sync.
/// - `InMemoryCatalogRepository`: navegadores viejos donde el wasm no corre;
///   vive solo en RAM, sin cursor (siempre seed completo) y sin offline.
abstract class CatalogLocalSource {
  Future<SyncCursor> readSyncState();

  Future<void> saveCursor(String serverTime);

  /// Aplica la página; devuelve true si hubo cambios de contenido.
  Future<bool> applyPage(SyncPage page);

  /// Borra el cursor de sync: la próxima corrida pide el catálogo COMPLETO
  /// (re-seed manual desde Configuración). Los datos locales NO se borran:
  /// el seed entrante los reemplaza por upsert, así que sin red se
  /// conservan y el próximo intento (o el arranque) pide el seed completo.
  Future<void> clearSyncState();

  Future<List<ProductDetailOut>> getProducts();

  Future<List<CategoryOut>> getCategories();

  Future<List<String>> getImageUrls();

  /// Etiqueta y stock local de una variación (diálogo de conflicto de stock).
  Future<({String label, int stock})?> getVariationInfo(int variationId);
}
