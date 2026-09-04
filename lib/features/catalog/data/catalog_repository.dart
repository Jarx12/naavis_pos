import 'package:dio/dio.dart';
import '../domain/product_model.dart';
import '../domain/category_model.dart';

class CatalogRepository {
  final Dio _dio;

  CatalogRepository(this._dio);

  Future<List<ProductDetailOut>> getProducts({int? categoryId, bool onlyVisible = true}) async {
    try {
      final response = await _dio.get(
        '/products',
        queryParameters: {
          // ignore: use_null_aware_elements
          if (categoryId != null) 'category_id': categoryId,
          'only_visible': onlyVisible,
        },
      );

      final List data = response.data;
      return data.map((json) => ProductDetailOut.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<CategoryOut>> getCategories() async {
    final response = await _dio.get('/categories');
    final List list = response.data;
    return list.map((json) => CategoryOut.fromJson(json)).toList();
  }
}