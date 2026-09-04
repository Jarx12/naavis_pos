// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProductDetailOut _$ProductDetailOutFromJson(Map<String, dynamic> json) =>
    _ProductDetailOut(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      finalPrice: (json['final_price'] as num).toDouble(),
      discountPercentage: (json['discount_percentage'] as num).toInt(),
      description: json['description'] as String,
      totalStock: (json['total_stock'] as num).toInt(),
      cost: (json['cost'] as num).toDouble(),
      isVisible: json['is_visible'] as bool,
      categories:
          (json['categories'] as List<dynamic>?)
              ?.map((e) => CategoryOut.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      variations:
          (json['variations'] as List<dynamic>?)
              ?.map((e) => VariationOut.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      images:
          (json['images'] as List<dynamic>?)
              ?.map((e) => ProductImageOut.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$ProductDetailOutToJson(_ProductDetailOut instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'price': instance.price,
      'final_price': instance.finalPrice,
      'discount_percentage': instance.discountPercentage,
      'description': instance.description,
      'total_stock': instance.totalStock,
      'cost': instance.cost,
      'is_visible': instance.isVisible,
      'categories': instance.categories,
      'variations': instance.variations,
      'images': instance.images,
    };

_ProductImageOut _$ProductImageOutFromJson(Map<String, dynamic> json) =>
    _ProductImageOut(
      id: (json['id'] as num).toInt(),
      imageUrl: json['image_url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      isMain: json['is_main'] as bool? ?? false,
    );

Map<String, dynamic> _$ProductImageOutToJson(_ProductImageOut instance) =>
    <String, dynamic>{
      'id': instance.id,
      'image_url': instance.imageUrl,
      'thumbnail_url': instance.thumbnailUrl,
      'is_main': instance.isMain,
    };

_VariationOut _$VariationOutFromJson(Map<String, dynamic> json) =>
    _VariationOut(
      id: (json['id'] as num).toInt(),
      variationType: json['variation_type'] as String,
      stock: (json['stock'] as num).toInt(),
      searchTags: json['search_tags'] as String?,
    );

Map<String, dynamic> _$VariationOutToJson(_VariationOut instance) =>
    <String, dynamic>{
      'id': instance.id,
      'variation_type': instance.variationType,
      'stock': instance.stock,
      'search_tags': instance.searchTags,
    };
