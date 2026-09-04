import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/catalog_repository.dart';
import '../../domain/product_model.dart';
import '../../domain/category_model.dart';


final catalogRepositoryProvider = Provider((ref) {
  final dio = ref.watch(dioClientProvider).dio;
  return CatalogRepository(dio);
});

final productsProvider = FutureProvider<List<ProductDetailOut>>((ref) async {
  final repository = ref.watch(catalogRepositoryProvider);
  return repository.getProducts(onlyVisible: true);
});


final categoriesProvider = FutureProvider<List<CategoryOut>>((ref) async {
  final repository = ref.watch(catalogRepositoryProvider);
  return repository.getCategories();
});