import '../../sync/data/sync_models.dart';
import '../domain/category_model.dart';
import '../domain/product_model.dart';
import 'catalog_local_source.dart';

/// Versión en memoria de [CatalogLocalSource] para los navegadores donde no
/// corre el sqlite3.wasm de Drift (ver `core/db/drift_web_gate.dart`).
///
/// Diferencias con la versión SQL:
/// - SIN cursor: no hay dónde persistir el catálogo, así que cada arranque
///   pide el seed completo al server (modo online-only).
/// - Los hijos (variantes/imágenes) viven DENTRO de [ProductDetailOut], así
///   que el "reemplazo completo" del delta es el upsert del producto ya
///   parseado; `deleted_*` se aplican igual que en la versión SQL.
class InMemoryCatalogRepository implements CatalogLocalSource {
  final Map<int, ProductDetailOut> _products = {};
  final Map<int, String> _categories = {};

  @override
  Future<SyncCursor> readSyncState() async => const SyncCursor();

  @override
  Future<void> saveCursor(String serverTime) async {}

  @override
  Future<bool> applyPage(SyncPage page) async {
    if (!page.hasContent && page.serverTime.isEmpty) return false;

    // 1) Tumbas primero: un payload jamás debe resucitar lo borrado.
    for (final id in page.deletedCategories) {
      _categories.remove(id);
    }
    for (final id in page.deletedProducts) {
      _products.remove(id);
    }
    for (final vid in page.deletedVariations) {
      for (final entry in _products.entries.toList()) {
        final variations = entry.value.variations;
        if (variations.any((v) => v.id == vid)) {
          _products[entry.key] = entry.value.copyWith(
            variations: [for (final v in variations) if (v.id != vid) v],
          );
        }
      }
    }

    // 2) Categorías top-level: siempre frescas (sobrescriben el nombre).
    for (final raw in page.categories) {
      final id = raw['id'] as int?;
      final name = raw['name']?.toString();
      if (id == null || name == null) continue;
      _categories[id] = name;
    }

    // 3) Productos: upsert del payload completo.
    for (final raw in page.products) {
      final id = raw['id'];
      if (id is! int) continue;
      final ProductDetailOut? parsed;
      try {
        parsed = ProductDetailOut.fromJson(raw);
      } catch (_) {
        // Payload inesperado: se ignora (el server lo arregla en el próximo
        // delta; la versión SQL guardaría defaults, aquí no hay columnas).
        continue;
      }
      // Mismas reglas que la versión SQL: los ids embebidos garantizan la
      // existencia de la categoría; el nombre fresco lo aporta la
      // colección top-level.
      for (final c in parsed.categories) {
        _categories.putIfAbsent(c.id, () => c.name);
      }
      _products[id] = parsed;
    }

    return page.hasContent;
  }

  @override
  Future<List<ProductDetailOut>> getProducts() async {
    final products = _products.values.map((p) {
      // Resuelve los nombres por join local (nunca los embebidos).
      final categories = [
        for (final c in p.categories)
          if (_categories[c.id] != null)
            CategoryOut(id: c.id, name: _categories[c.id]!),
      ];
      return p.copyWith(categories: categories);
    }).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return products;
  }

  @override
  Future<List<CategoryOut>> getCategories() async {
    final ids = _categories.keys.toList()..sort();
    return [for (final id in ids) CategoryOut(id: id, name: _categories[id]!)];
  }

  @override
  Future<List<String>> getImageUrls() async {
    return [
      for (final p in _products.values)
        for (final img in p.images)
          if (img.imageUrl.isNotEmpty) img.imageUrl,
    ];
  }

  @override
  Future<({String label, int stock})?> getVariationInfo(
      int variationId) async {
    for (final p in _products.values) {
      for (final v in p.variations) {
        if (v.id == variationId) {
          return (label: '${p.name} (${v.variationType})', stock: v.stock);
        }
      }
    }
    return null;
  }
}
