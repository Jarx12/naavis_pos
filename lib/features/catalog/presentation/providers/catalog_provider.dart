import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../sync/data/sync_service.dart';
import '../../data/local_catalog_repository.dart';
import '../../domain/category_model.dart';
import '../../domain/product_model.dart';

/// Productos desde la CACHÉ LOCAL (drift).
///
/// - Base vacía (primer arranque): espera el seed antes de responder.
/// - Base poblada: responde de inmediato con la caché y dispara un delta
///   en segundo plano; solo se refresca la UI si el server trajo cambios.
final productsProvider = FutureProvider<List<ProductDetailOut>>((ref) async {
  final local = ref.watch(localCatalogProvider);

  var products = await local.getProducts();
  if (products.isEmpty) {
    final result = await ref.read(syncServiceProvider).sync();
    if (result.ok) products = await local.getProducts();
    return products;
  }

  ref.read(syncServiceProvider).sync().then((result) {
    if (ref.mounted && result.ok && result.changed) ref.invalidateSelf();
  });
  return products;
});

/// Categorías desde la caché local; mismo flujo que [productsProvider].
final categoriesProvider = FutureProvider<List<CategoryOut>>((ref) async {
  final local = ref.watch(localCatalogProvider);

  var categories = await local.getCategories();
  if (categories.isEmpty) {
    final result = await ref.read(syncServiceProvider).sync();
    if (result.ok) categories = await local.getCategories();
  }
  return categories;
});