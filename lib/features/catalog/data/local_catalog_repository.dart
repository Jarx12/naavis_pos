import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/app_providers.dart';
import '../../sync/data/sync_models.dart';
import '../domain/category_model.dart';
import '../domain/product_model.dart';
import 'catalog_local_source.dart';
import 'in_memory_catalog_repository.dart';

/// Acceso en LECTURA a la caché local del catálogo + aplicación de deltas.
///
/// Reglas importantes:
/// - Los hijos de un producto (variantes/imágenes/joins) se REEMPLAZAN
///   completos en cada payload: el delta siempre trae el producto entero.
/// - Los `categories` embebidos en un producto solo se insertan si el id no
///   existe localmente (pueden traer un nombre viejo tras un rename); el
///   nombre fresco siempre lo aporta la colección `categories` top-level
///   del delta, que viene leída en el momento de la query.
/// - Al borrar una categoría se purgan también sus joins.
class LocalCatalogRepository implements CatalogLocalSource {
  final AppDatabase _db;

  LocalCatalogRepository(this._db);

  // ── Cursor ────────────────────────────────────────────────────────

  @override
  Future<SyncCursor> readSyncState() async {
    final row = await (_db.select(_db.syncState)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    return SyncCursor(
      serverTime: row?.serverTime,
      seeded: row?.seeded ?? false,
    );
  }

  @override
  Future<void> saveCursor(String serverTime) async {
    await _db.into(_db.syncState).insertOnConflictUpdate(
          SyncStateData(id: 1, serverTime: serverTime, seeded: true),
        );
  }

  @override
  Future<void> clearSyncState() async {
    await (_db.delete(_db.syncState)..where((t) => t.id.equals(1))).go();
  }

  // ── Aplicar una página de sync ────────────────────────────────────

  /// Aplica la página en una sola transacción. Devuelve true si hubo
  /// cambios de contenido (para que el llamador decida si invalida la UI).
  @override
  Future<bool> applyPage(SyncPage page) async {
    if (!page.hasContent && page.serverTime.isEmpty) return false;

    await _db.transaction(() async {
      // 1) Tumbas primero: un payload jamás debe resucitar lo borrado.
      for (final id in page.deletedCategories) {
        await (_db.delete(_db.productCategories)
              ..where((t) => t.categoryId.equals(id)))
            .go();
        await (_db.delete(_db.categories)..where((t) => t.id.equals(id))).go();
      }
      for (final id in page.deletedVariations) {
        await (_db.delete(_db.variations)..where((t) => t.id.equals(id))).go();
      }
      for (final id in page.deletedProducts) {
        await _deleteProductChildren(id);
        await (_db.delete(_db.products)..where((t) => t.id.equals(id))).go();
      }

      // 2) Categorías top-level: siempre frescas (query en el momento),
      //    aquí sí se sobrescribe el nombre.
      for (final raw in page.categories) {
        final id = raw['id'] as int?;
        final name = raw['name'] as String?;
        if (id == null || name == null) continue;
        await _db
            .into(_db.categories)
            .insertOnConflictUpdate(Category(id: id, name: name));
      }

      // 3) Productos: fila + hijos completos.
      for (final raw in page.products) {
        await _upsertProduct(raw);
      }
    });

    return page.hasContent;
  }

  Future<void> _deleteProductChildren(int productId) async {
    await (_db.delete(_db.variations)
          ..where((t) => t.productId.equals(productId)))
        .go();
    await (_db.delete(_db.productImages)
          ..where((t) => t.productId.equals(productId)))
        .go();
    await (_db.delete(_db.productCategories)
          ..where((t) => t.productId.equals(productId)))
        .go();
  }

  Future<void> _upsertProduct(Map<String, dynamic> raw) async {
    final id = _asInt(raw['id']);
    if (id == null) return;

    await _db.into(_db.products).insertOnConflictUpdate(Product(
          id: id,
          name: raw['name']?.toString() ?? '',
          price: _asDouble(raw['price']) ?? 0,
          finalPrice: _asDouble(raw['final_price']) ?? 0,
          discountPercentage: _asInt(raw['discount_percentage']) ?? 0,
          description: raw['description']?.toString() ?? '',
          totalStock: _asInt(raw['total_stock']) ?? 0,
          cost: _asDouble(raw['cost']) ?? 0,
          isVisible: raw['is_visible'] as bool? ?? true,
        ));

    // Hijos: reemplazo completo.
    await _deleteProductChildren(id);

    final variations = (raw['variations'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>();
    for (final v in variations) {
      final vid = _asInt(v['id']);
      if (vid == null) continue;
      await _db.into(_db.variations).insert(
            Variation(
              id: vid,
              productId: id,
              variationType: v['variation_type']?.toString() ?? '',
              stock: _asInt(v['stock']) ?? 0,
              searchTags: v['search_tags']?.toString(),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }

    final images =
        (raw['images'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>();
    for (final img in images) {
      final imgId = _asInt(img['id']);
      final imageUrl = img['image_url']?.toString();
      if (imgId == null || imageUrl == null || imageUrl.isEmpty) {
        // Sin URL no sirve para nada en el POS; se descarta.
        continue;
      }
      await _db.into(_db.productImages).insert(
            ProductImage(
              id: imgId,
              productId: id,
              imageUrl: imageUrl,
              thumbnailUrl: img['thumbnail_url']?.toString(),
              isMain: img['is_main'] as bool? ?? false,
              variationIds: jsonEncode(_asIntList(img['variation_ids'])),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }

    // Joins: ids del payload. El nombre NO se copia desde aquí (puede estar
    // obsoleto tras un rename): solo se garantiza que el id exista en la
    // tabla `categories`; si no existe se crea con el nombre embebido.
    final embeddedCategories =
        (raw['categories'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>();
    for (final c in embeddedCategories) {
      final cid = _asInt(c['id']);
      final cname = c['name']?.toString();
      if (cid == null) continue;

      final exists = await (_db.select(_db.categories)
            ..where((t) => t.id.equals(cid)))
          .getSingleOrNull();
      if (exists == null && cname != null) {
        await _db.into(_db.categories).insert(Category(id: cid, name: cname));
      }
      await _db.into(_db.productCategories).insert(
            ProductCategory(productId: id, categoryId: cid),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }

  // ── Lecturas ──────────────────────────────────────────────────────

  /// Todos los productos con sus hijos ya resueltos. Los `categories` del
  /// modelo se arman con el JOIN a la tabla `categories` (nombres frescos),
  /// nunca con la copia embebida del payload.
  @override
  Future<List<ProductDetailOut>> getProducts() async {
    final productRows = await (_db.select(_db.products)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    if (productRows.isEmpty) return [];

    final variationRows = await _db.select(_db.variations).get();
    final imageRows = await _db.select(_db.productImages).get();
    final joinRows = await _db.select(_db.productCategories).get();
    final categoryRows = await _db.select(_db.categories).get();

    final categoryNames = {for (final c in categoryRows) c.id: c.name};

    final variationsByProduct = <int, List<VariationOut>>{};
    for (final v in variationRows) {
      variationsByProduct.putIfAbsent(v.productId, () => []).add(
            VariationOut(
              id: v.id,
              variationType: v.variationType,
              stock: v.stock,
              searchTags: v.searchTags,
            ),
          );
    }

    final imagesByProduct = <int, List<ProductImageOut>>{};
    for (final img in imageRows) {
      final url = img.imageUrl;
      if (url == null || url.isEmpty) continue;
      imagesByProduct.putIfAbsent(img.productId, () => []).add(
            ProductImageOut(
              id: img.id,
              imageUrl: url,
              thumbnailUrl: img.thumbnailUrl,
              isMain: img.isMain,
              variationIds: _decodeIdList(img.variationIds),
            ),
          );
    }

    final categoryIdsByProduct = <int, List<int>>{};
    for (final j in joinRows) {
      categoryIdsByProduct.putIfAbsent(j.productId, () => []).add(j.categoryId);
    }

    return [
      for (final p in productRows)
        ProductDetailOut(
          id: p.id,
          name: p.name,
          price: p.price,
          finalPrice: p.finalPrice,
          discountPercentage: p.discountPercentage,
          description: p.description,
          totalStock: p.totalStock,
          cost: p.cost,
          isVisible: p.isVisible,
          categories: [
            for (final cid in categoryIdsByProduct[p.id] ?? const <int>[])
              if (categoryNames[cid] != null)
                CategoryOut(id: cid, name: categoryNames[cid]!),
          ],
          variations: variationsByProduct[p.id] ?? const [],
          images: imagesByProduct[p.id] ?? const [],
        ),
    ];
  }

  @override
  Future<List<CategoryOut>> getCategories() async {
    final rows = await (_db.select(_db.categories)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    return [for (final c in rows) CategoryOut(id: c.id, name: c.name)];
  }

  /// URLs crudas (tal cual las guardó el server) de todas las fotos del
  /// catálogo local. Las usa el prefetch de la sync para bajarlas a la
  /// caché de disco: leer desde la DB (y no solo desde las páginas del
  /// delta) permite retomar un precache interrumpido aunque la próxima
  /// sync no traiga cambios de contenido.
  @override
  Future<List<String>> getImageUrls() async {
    final rows = await _db.select(_db.productImages).get();
    return [
      for (final r in rows)
        if (r.imageUrl != null && r.imageUrl!.isNotEmpty) r.imageUrl!,
    ];
  }

  /// Etiqueta y stock local de una variación (diálogo de conflicto de stock).
  @override
  Future<({String label, int stock})?> getVariationInfo(
      int variationId) async {
    final query = _db.select(_db.variations).join([
      innerJoin(
          _db.products, _db.products.id.equalsExp(_db.variations.productId)),
    ])
      ..where(_db.variations.id.equals(variationId));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    final v = row.readTable(_db.variations);
    final p = row.readTable(_db.products);
    return (label: '${p.name} (${v.variationType})', stock: v.stock);
  }

  static int? _asInt(dynamic v) =>
      v is int ? v : (v is num ? v.toInt() : null);
  static double? _asDouble(dynamic v) =>
      v is double ? v : (v is num ? v.toDouble() : null);

  /// Lista de ids desde el payload (`variation_ids`); malformada → vacía.
  static List<int> _asIntList(dynamic v) {
    if (v is! List) return const [];
    final ids = <int>[];
    for (final e in v) {
      final id = _asInt(e);
      if (id != null) ids.add(id);
    }
    return ids;
  }

  /// Columna JSON "[452,453]" → lista de ids (nula/corrupta → vacía).
  static List<int> _decodeIdList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      return _asIntList(jsonDecode(raw));
    } catch (_) {
      return const [];
    }
  }
}

final localCatalogProvider = Provider<CatalogLocalSource>((ref) {
  // Navegador sin soporte del wasm de drift: catálogo solo en memoria
  // (modo online-only; ver core/db/drift_web_gate.dart).
  if (kIsWeb && !ref.watch(driftStorageAvailableProvider)) {
    return InMemoryCatalogRepository();
  }
  return LocalCatalogRepository(ref.watch(appDatabaseProvider));
});
