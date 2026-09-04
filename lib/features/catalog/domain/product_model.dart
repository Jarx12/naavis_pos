import 'package:freezed_annotation/freezed_annotation.dart';
import 'category_model.dart';

part 'product_model.freezed.dart';
part 'product_model.g.dart';


@freezed
abstract class ProductDetailOut with _$ProductDetailOut {
  const ProductDetailOut._(); // Requerido por Freezed para agregar getters personalizados

  const factory ProductDetailOut({
    required int id,
    required String name,
    required double price,
    @JsonKey(name: 'final_price') required double finalPrice,
    @JsonKey(name: 'discount_percentage') required int discountPercentage,
    required String description,
    @JsonKey(name: 'total_stock') required int totalStock,
    required double cost,
    @JsonKey(name: 'is_visible') required bool isVisible,
    @Default([]) List<CategoryOut> categories,
    @Default([]) List<VariationOut> variations,
    @Default([]) List<ProductImageOut> images,
  }) = _ProductDetailOut;

  factory ProductDetailOut.fromJson(Map<String, dynamic> json) =>
      _$ProductDetailOutFromJson(json);

  /// Retorna la URL completa combinando la baseUrl de Dio con la ruta de la imagen
  String? getMainImageUrl(String baseUrl) {
    if (images.isEmpty) return null;

    final mainImage = images.firstWhere(
      (img) => img.isMain,
      orElse: () => images.first,
    );

    final cleanBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    final imagePath = mainImage.imageUrl;

    if (imagePath.startsWith('http')) {
      return imagePath;
    }

    return '$cleanBaseUrl$imagePath';
  }
}

@freezed
abstract class ProductImageOut with _$ProductImageOut {
  const factory ProductImageOut({
    required int id,
    @JsonKey(name: 'image_url') required String imageUrl,
    @JsonKey(name: 'thumbnail_url') String? thumbnailUrl,
    @JsonKey(name: 'is_main') @Default(false) bool isMain,
  }) = _ProductImageOut;

  factory ProductImageOut.fromJson(Map<String, dynamic> json) =>
      _$ProductImageOutFromJson(json);
}

@freezed
abstract class VariationOut with _$VariationOut {
  const factory VariationOut({
    required int id,
    @JsonKey(name: 'variation_type') required String variationType,
    required int stock,
    @JsonKey(name: 'search_tags') String? searchTags,
  }) = _VariationOut;

  factory VariationOut.fromJson(Map<String, dynamic> json) =>
      _$VariationOutFromJson(json);
}