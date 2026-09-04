// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'product_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProductDetailOut {

 int get id; String get name; double get price;@JsonKey(name: 'final_price') double get finalPrice;@JsonKey(name: 'discount_percentage') int get discountPercentage; String get description;@JsonKey(name: 'total_stock') int get totalStock; double get cost;@JsonKey(name: 'is_visible') bool get isVisible; List<CategoryOut> get categories; List<VariationOut> get variations; List<ProductImageOut> get images;
/// Create a copy of ProductDetailOut
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductDetailOutCopyWith<ProductDetailOut> get copyWith => _$ProductDetailOutCopyWithImpl<ProductDetailOut>(this as ProductDetailOut, _$identity);

  /// Serializes this ProductDetailOut to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ProductDetailOut;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductDetailOut&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.price, _this.price) || other.price == _this.price)&&(identical(other.finalPrice, _this.finalPrice) || other.finalPrice == _this.finalPrice)&&(identical(other.discountPercentage, _this.discountPercentage) || other.discountPercentage == _this.discountPercentage)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.totalStock, _this.totalStock) || other.totalStock == _this.totalStock)&&(identical(other.cost, _this.cost) || other.cost == _this.cost)&&(identical(other.isVisible, _this.isVisible) || other.isVisible == _this.isVisible)&&const DeepCollectionEquality().equals(other.categories, _this.categories)&&const DeepCollectionEquality().equals(other.variations, _this.variations)&&const DeepCollectionEquality().equals(other.images, _this.images));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ProductDetailOut;
  return Object.hash(runtimeType,_this.id,_this.name,_this.price,_this.finalPrice,_this.discountPercentage,_this.description,_this.totalStock,_this.cost,_this.isVisible,const DeepCollectionEquality().hash(_this.categories),const DeepCollectionEquality().hash(_this.variations),const DeepCollectionEquality().hash(_this.images));
}

@override
String toString() {
  final _this = this as ProductDetailOut;
  return 'ProductDetailOut(id: ${_this.id}, name: ${_this.name}, price: ${_this.price}, finalPrice: ${_this.finalPrice}, discountPercentage: ${_this.discountPercentage}, description: ${_this.description}, totalStock: ${_this.totalStock}, cost: ${_this.cost}, isVisible: ${_this.isVisible}, categories: ${_this.categories}, variations: ${_this.variations}, images: ${_this.images})';
}


}

/// @nodoc
abstract mixin class $ProductDetailOutCopyWith<$Res>  {
  factory $ProductDetailOutCopyWith(ProductDetailOut value, $Res Function(ProductDetailOut) _then) = _$ProductDetailOutCopyWithImpl;
@useResult
$Res call({
 int id, String name, double price,@JsonKey(name: 'final_price') double finalPrice,@JsonKey(name: 'discount_percentage') int discountPercentage, String description,@JsonKey(name: 'total_stock') int totalStock, double cost,@JsonKey(name: 'is_visible') bool isVisible, List<CategoryOut> categories, List<VariationOut> variations, List<ProductImageOut> images
});




}
/// @nodoc
class _$ProductDetailOutCopyWithImpl<$Res>
    implements $ProductDetailOutCopyWith<$Res> {
  _$ProductDetailOutCopyWithImpl(this._self, this._then);

  final ProductDetailOut _self;
  final $Res Function(ProductDetailOut) _then;

/// Create a copy of ProductDetailOut
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? price = null,Object? finalPrice = null,Object? discountPercentage = null,Object? description = null,Object? totalStock = null,Object? cost = null,Object? isVisible = null,Object? categories = null,Object? variations = null,Object? images = null,}) {
  return _then(ProductDetailOut(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double,finalPrice: null == finalPrice ? _self.finalPrice : finalPrice // ignore: cast_nullable_to_non_nullable
as double,discountPercentage: null == discountPercentage ? _self.discountPercentage : discountPercentage // ignore: cast_nullable_to_non_nullable
as int,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,totalStock: null == totalStock ? _self.totalStock : totalStock // ignore: cast_nullable_to_non_nullable
as int,cost: null == cost ? _self.cost : cost // ignore: cast_nullable_to_non_nullable
as double,isVisible: null == isVisible ? _self.isVisible : isVisible // ignore: cast_nullable_to_non_nullable
as bool,categories: null == categories ? _self.categories : categories // ignore: cast_nullable_to_non_nullable
as List<CategoryOut>,variations: null == variations ? _self.variations : variations // ignore: cast_nullable_to_non_nullable
as List<VariationOut>,images: null == images ? _self.images : images // ignore: cast_nullable_to_non_nullable
as List<ProductImageOut>,
  ));
}

}


/// Adds pattern-matching-related methods to [ProductDetailOut].
extension ProductDetailOutPatterns on ProductDetailOut {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProductDetailOut value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProductDetailOut() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProductDetailOut value)  $default,){
final _that = this;
switch (_that) {
case _ProductDetailOut():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProductDetailOut value)?  $default,){
final _that = this;
switch (_that) {
case _ProductDetailOut() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name,  double price, @JsonKey(name: 'final_price')  double finalPrice, @JsonKey(name: 'discount_percentage')  int discountPercentage,  String description, @JsonKey(name: 'total_stock')  int totalStock,  double cost, @JsonKey(name: 'is_visible')  bool isVisible,  List<CategoryOut> categories,  List<VariationOut> variations,  List<ProductImageOut> images)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProductDetailOut() when $default != null:
return $default(_that.id,_that.name,_that.price,_that.finalPrice,_that.discountPercentage,_that.description,_that.totalStock,_that.cost,_that.isVisible,_that.categories,_that.variations,_that.images);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name,  double price, @JsonKey(name: 'final_price')  double finalPrice, @JsonKey(name: 'discount_percentage')  int discountPercentage,  String description, @JsonKey(name: 'total_stock')  int totalStock,  double cost, @JsonKey(name: 'is_visible')  bool isVisible,  List<CategoryOut> categories,  List<VariationOut> variations,  List<ProductImageOut> images)  $default,) {final _that = this;
switch (_that) {
case _ProductDetailOut():
return $default(_that.id,_that.name,_that.price,_that.finalPrice,_that.discountPercentage,_that.description,_that.totalStock,_that.cost,_that.isVisible,_that.categories,_that.variations,_that.images);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name,  double price, @JsonKey(name: 'final_price')  double finalPrice, @JsonKey(name: 'discount_percentage')  int discountPercentage,  String description, @JsonKey(name: 'total_stock')  int totalStock,  double cost, @JsonKey(name: 'is_visible')  bool isVisible,  List<CategoryOut> categories,  List<VariationOut> variations,  List<ProductImageOut> images)?  $default,) {final _that = this;
switch (_that) {
case _ProductDetailOut() when $default != null:
return $default(_that.id,_that.name,_that.price,_that.finalPrice,_that.discountPercentage,_that.description,_that.totalStock,_that.cost,_that.isVisible,_that.categories,_that.variations,_that.images);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProductDetailOut extends ProductDetailOut {
  const _ProductDetailOut({required this.id, required this.name, required this.price, @JsonKey(name: 'final_price') required this.finalPrice, @JsonKey(name: 'discount_percentage') required this.discountPercentage, required this.description, @JsonKey(name: 'total_stock') required this.totalStock, required this.cost, @JsonKey(name: 'is_visible') required this.isVisible,  List<CategoryOut> categories = const [],  List<VariationOut> variations = const [],  List<ProductImageOut> images = const []}): _categories = categories,_variations = variations,_images = images,super._();
  factory _ProductDetailOut.fromJson(Map<String, dynamic> json) => _$ProductDetailOutFromJson(json);

@override final  int id;
@override final  String name;
@override final  double price;
@override@JsonKey(name: 'final_price') final  double finalPrice;
@override@JsonKey(name: 'discount_percentage') final  int discountPercentage;
@override final  String description;
@override@JsonKey(name: 'total_stock') final  int totalStock;
@override final  double cost;
@override@JsonKey(name: 'is_visible') final  bool isVisible;
 final  List<CategoryOut> _categories;
@override@JsonKey() List<CategoryOut> get categories {
  if (_categories is EqualUnmodifiableListView) return _categories;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_categories);
}

 final  List<VariationOut> _variations;
@override@JsonKey() List<VariationOut> get variations {
  if (_variations is EqualUnmodifiableListView) return _variations;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_variations);
}

 final  List<ProductImageOut> _images;
@override@JsonKey() List<ProductImageOut> get images {
  if (_images is EqualUnmodifiableListView) return _images;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_images);
}


/// Create a copy of ProductDetailOut
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProductDetailOutCopyWith<_ProductDetailOut> get copyWith => __$ProductDetailOutCopyWithImpl<_ProductDetailOut>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProductDetailOutToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProductDetailOut&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.price, price) || other.price == price)&&(identical(other.finalPrice, finalPrice) || other.finalPrice == finalPrice)&&(identical(other.discountPercentage, discountPercentage) || other.discountPercentage == discountPercentage)&&(identical(other.description, description) || other.description == description)&&(identical(other.totalStock, totalStock) || other.totalStock == totalStock)&&(identical(other.cost, cost) || other.cost == cost)&&(identical(other.isVisible, isVisible) || other.isVisible == isVisible)&&const DeepCollectionEquality().equals(other.categories, _categories)&&const DeepCollectionEquality().equals(other.variations, _variations)&&const DeepCollectionEquality().equals(other.images, _images));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,price,finalPrice,discountPercentage,description,totalStock,cost,isVisible,const DeepCollectionEquality().hash(_categories),const DeepCollectionEquality().hash(_variations),const DeepCollectionEquality().hash(_images));
}

@override
String toString() {
    return 'ProductDetailOut(id: $id, name: $name, price: $price, finalPrice: $finalPrice, discountPercentage: $discountPercentage, description: $description, totalStock: $totalStock, cost: $cost, isVisible: $isVisible, categories: $categories, variations: $variations, images: $images)';
}


}

/// @nodoc
abstract mixin class _$ProductDetailOutCopyWith<$Res> implements $ProductDetailOutCopyWith<$Res> {
  factory _$ProductDetailOutCopyWith(_ProductDetailOut value, $Res Function(_ProductDetailOut) _then) = __$ProductDetailOutCopyWithImpl;
@override @useResult
$Res call({
 int id, String name, double price,@JsonKey(name: 'final_price') double finalPrice,@JsonKey(name: 'discount_percentage') int discountPercentage, String description,@JsonKey(name: 'total_stock') int totalStock, double cost,@JsonKey(name: 'is_visible') bool isVisible, List<CategoryOut> categories, List<VariationOut> variations, List<ProductImageOut> images
});




}
/// @nodoc
class __$ProductDetailOutCopyWithImpl<$Res>
    implements _$ProductDetailOutCopyWith<$Res> {
  __$ProductDetailOutCopyWithImpl(this._self, this._then);

  final _ProductDetailOut _self;
  final $Res Function(_ProductDetailOut) _then;

/// Create a copy of ProductDetailOut
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? price = null,Object? finalPrice = null,Object? discountPercentage = null,Object? description = null,Object? totalStock = null,Object? cost = null,Object? isVisible = null,Object? categories = null,Object? variations = null,Object? images = null,}) {
  return _then(_ProductDetailOut(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double,finalPrice: null == finalPrice ? _self.finalPrice : finalPrice // ignore: cast_nullable_to_non_nullable
as double,discountPercentage: null == discountPercentage ? _self.discountPercentage : discountPercentage // ignore: cast_nullable_to_non_nullable
as int,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,totalStock: null == totalStock ? _self.totalStock : totalStock // ignore: cast_nullable_to_non_nullable
as int,cost: null == cost ? _self.cost : cost // ignore: cast_nullable_to_non_nullable
as double,isVisible: null == isVisible ? _self.isVisible : isVisible // ignore: cast_nullable_to_non_nullable
as bool,categories: null == categories ? _self._categories : categories // ignore: cast_nullable_to_non_nullable
as List<CategoryOut>,variations: null == variations ? _self._variations : variations // ignore: cast_nullable_to_non_nullable
as List<VariationOut>,images: null == images ? _self._images : images // ignore: cast_nullable_to_non_nullable
as List<ProductImageOut>,
  ));
}


}


/// @nodoc
mixin _$ProductImageOut {

 int get id;@JsonKey(name: 'image_url') String get imageUrl;@JsonKey(name: 'thumbnail_url') String? get thumbnailUrl;@JsonKey(name: 'is_main') bool get isMain;
/// Create a copy of ProductImageOut
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductImageOutCopyWith<ProductImageOut> get copyWith => _$ProductImageOutCopyWithImpl<ProductImageOut>(this as ProductImageOut, _$identity);

  /// Serializes this ProductImageOut to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ProductImageOut;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductImageOut&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.imageUrl, _this.imageUrl) || other.imageUrl == _this.imageUrl)&&(identical(other.thumbnailUrl, _this.thumbnailUrl) || other.thumbnailUrl == _this.thumbnailUrl)&&(identical(other.isMain, _this.isMain) || other.isMain == _this.isMain));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ProductImageOut;
  return Object.hash(runtimeType,_this.id,_this.imageUrl,_this.thumbnailUrl,_this.isMain);
}

@override
String toString() {
  final _this = this as ProductImageOut;
  return 'ProductImageOut(id: ${_this.id}, imageUrl: ${_this.imageUrl}, thumbnailUrl: ${_this.thumbnailUrl}, isMain: ${_this.isMain})';
}


}

/// @nodoc
abstract mixin class $ProductImageOutCopyWith<$Res>  {
  factory $ProductImageOutCopyWith(ProductImageOut value, $Res Function(ProductImageOut) _then) = _$ProductImageOutCopyWithImpl;
@useResult
$Res call({
 int id,@JsonKey(name: 'image_url') String imageUrl,@JsonKey(name: 'thumbnail_url') String? thumbnailUrl,@JsonKey(name: 'is_main') bool isMain
});




}
/// @nodoc
class _$ProductImageOutCopyWithImpl<$Res>
    implements $ProductImageOutCopyWith<$Res> {
  _$ProductImageOutCopyWithImpl(this._self, this._then);

  final ProductImageOut _self;
  final $Res Function(ProductImageOut) _then;

/// Create a copy of ProductImageOut
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? imageUrl = null,Object? thumbnailUrl = freezed,Object? isMain = null,}) {
  return _then(ProductImageOut(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,isMain: null == isMain ? _self.isMain : isMain // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ProductImageOut].
extension ProductImageOutPatterns on ProductImageOut {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProductImageOut value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProductImageOut() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProductImageOut value)  $default,){
final _that = this;
switch (_that) {
case _ProductImageOut():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProductImageOut value)?  $default,){
final _that = this;
switch (_that) {
case _ProductImageOut() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'image_url')  String imageUrl, @JsonKey(name: 'thumbnail_url')  String? thumbnailUrl, @JsonKey(name: 'is_main')  bool isMain)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProductImageOut() when $default != null:
return $default(_that.id,_that.imageUrl,_that.thumbnailUrl,_that.isMain);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'image_url')  String imageUrl, @JsonKey(name: 'thumbnail_url')  String? thumbnailUrl, @JsonKey(name: 'is_main')  bool isMain)  $default,) {final _that = this;
switch (_that) {
case _ProductImageOut():
return $default(_that.id,_that.imageUrl,_that.thumbnailUrl,_that.isMain);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id, @JsonKey(name: 'image_url')  String imageUrl, @JsonKey(name: 'thumbnail_url')  String? thumbnailUrl, @JsonKey(name: 'is_main')  bool isMain)?  $default,) {final _that = this;
switch (_that) {
case _ProductImageOut() when $default != null:
return $default(_that.id,_that.imageUrl,_that.thumbnailUrl,_that.isMain);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProductImageOut implements ProductImageOut {
  const _ProductImageOut({required this.id, @JsonKey(name: 'image_url') required this.imageUrl, @JsonKey(name: 'thumbnail_url') this.thumbnailUrl, @JsonKey(name: 'is_main') this.isMain = false});
  factory _ProductImageOut.fromJson(Map<String, dynamic> json) => _$ProductImageOutFromJson(json);

@override final  int id;
@override@JsonKey(name: 'image_url') final  String imageUrl;
@override@JsonKey(name: 'thumbnail_url') final  String? thumbnailUrl;
@override@JsonKey(name: 'is_main') final  bool isMain;

/// Create a copy of ProductImageOut
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProductImageOutCopyWith<_ProductImageOut> get copyWith => __$ProductImageOutCopyWithImpl<_ProductImageOut>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProductImageOutToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProductImageOut&&(identical(other.id, id) || other.id == id)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl)&&(identical(other.isMain, isMain) || other.isMain == isMain));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,imageUrl,thumbnailUrl,isMain);
}

@override
String toString() {
    return 'ProductImageOut(id: $id, imageUrl: $imageUrl, thumbnailUrl: $thumbnailUrl, isMain: $isMain)';
}


}

/// @nodoc
abstract mixin class _$ProductImageOutCopyWith<$Res> implements $ProductImageOutCopyWith<$Res> {
  factory _$ProductImageOutCopyWith(_ProductImageOut value, $Res Function(_ProductImageOut) _then) = __$ProductImageOutCopyWithImpl;
@override @useResult
$Res call({
 int id,@JsonKey(name: 'image_url') String imageUrl,@JsonKey(name: 'thumbnail_url') String? thumbnailUrl,@JsonKey(name: 'is_main') bool isMain
});




}
/// @nodoc
class __$ProductImageOutCopyWithImpl<$Res>
    implements _$ProductImageOutCopyWith<$Res> {
  __$ProductImageOutCopyWithImpl(this._self, this._then);

  final _ProductImageOut _self;
  final $Res Function(_ProductImageOut) _then;

/// Create a copy of ProductImageOut
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? imageUrl = null,Object? thumbnailUrl = freezed,Object? isMain = null,}) {
  return _then(_ProductImageOut(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,isMain: null == isMain ? _self.isMain : isMain // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$VariationOut {

 int get id;@JsonKey(name: 'variation_type') String get variationType; int get stock;@JsonKey(name: 'search_tags') String? get searchTags;
/// Create a copy of VariationOut
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VariationOutCopyWith<VariationOut> get copyWith => _$VariationOutCopyWithImpl<VariationOut>(this as VariationOut, _$identity);

  /// Serializes this VariationOut to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as VariationOut;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VariationOut&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.variationType, _this.variationType) || other.variationType == _this.variationType)&&(identical(other.stock, _this.stock) || other.stock == _this.stock)&&(identical(other.searchTags, _this.searchTags) || other.searchTags == _this.searchTags));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as VariationOut;
  return Object.hash(runtimeType,_this.id,_this.variationType,_this.stock,_this.searchTags);
}

@override
String toString() {
  final _this = this as VariationOut;
  return 'VariationOut(id: ${_this.id}, variationType: ${_this.variationType}, stock: ${_this.stock}, searchTags: ${_this.searchTags})';
}


}

/// @nodoc
abstract mixin class $VariationOutCopyWith<$Res>  {
  factory $VariationOutCopyWith(VariationOut value, $Res Function(VariationOut) _then) = _$VariationOutCopyWithImpl;
@useResult
$Res call({
 int id,@JsonKey(name: 'variation_type') String variationType, int stock,@JsonKey(name: 'search_tags') String? searchTags
});




}
/// @nodoc
class _$VariationOutCopyWithImpl<$Res>
    implements $VariationOutCopyWith<$Res> {
  _$VariationOutCopyWithImpl(this._self, this._then);

  final VariationOut _self;
  final $Res Function(VariationOut) _then;

/// Create a copy of VariationOut
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? variationType = null,Object? stock = null,Object? searchTags = freezed,}) {
  return _then(VariationOut(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,variationType: null == variationType ? _self.variationType : variationType // ignore: cast_nullable_to_non_nullable
as String,stock: null == stock ? _self.stock : stock // ignore: cast_nullable_to_non_nullable
as int,searchTags: freezed == searchTags ? _self.searchTags : searchTags // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [VariationOut].
extension VariationOutPatterns on VariationOut {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VariationOut value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VariationOut() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VariationOut value)  $default,){
final _that = this;
switch (_that) {
case _VariationOut():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VariationOut value)?  $default,){
final _that = this;
switch (_that) {
case _VariationOut() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'variation_type')  String variationType,  int stock, @JsonKey(name: 'search_tags')  String? searchTags)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VariationOut() when $default != null:
return $default(_that.id,_that.variationType,_that.stock,_that.searchTags);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'variation_type')  String variationType,  int stock, @JsonKey(name: 'search_tags')  String? searchTags)  $default,) {final _that = this;
switch (_that) {
case _VariationOut():
return $default(_that.id,_that.variationType,_that.stock,_that.searchTags);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id, @JsonKey(name: 'variation_type')  String variationType,  int stock, @JsonKey(name: 'search_tags')  String? searchTags)?  $default,) {final _that = this;
switch (_that) {
case _VariationOut() when $default != null:
return $default(_that.id,_that.variationType,_that.stock,_that.searchTags);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VariationOut implements VariationOut {
  const _VariationOut({required this.id, @JsonKey(name: 'variation_type') required this.variationType, required this.stock, @JsonKey(name: 'search_tags') this.searchTags});
  factory _VariationOut.fromJson(Map<String, dynamic> json) => _$VariationOutFromJson(json);

@override final  int id;
@override@JsonKey(name: 'variation_type') final  String variationType;
@override final  int stock;
@override@JsonKey(name: 'search_tags') final  String? searchTags;

/// Create a copy of VariationOut
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VariationOutCopyWith<_VariationOut> get copyWith => __$VariationOutCopyWithImpl<_VariationOut>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VariationOutToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VariationOut&&(identical(other.id, id) || other.id == id)&&(identical(other.variationType, variationType) || other.variationType == variationType)&&(identical(other.stock, stock) || other.stock == stock)&&(identical(other.searchTags, searchTags) || other.searchTags == searchTags));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,variationType,stock,searchTags);
}

@override
String toString() {
    return 'VariationOut(id: $id, variationType: $variationType, stock: $stock, searchTags: $searchTags)';
}


}

/// @nodoc
abstract mixin class _$VariationOutCopyWith<$Res> implements $VariationOutCopyWith<$Res> {
  factory _$VariationOutCopyWith(_VariationOut value, $Res Function(_VariationOut) _then) = __$VariationOutCopyWithImpl;
@override @useResult
$Res call({
 int id,@JsonKey(name: 'variation_type') String variationType, int stock,@JsonKey(name: 'search_tags') String? searchTags
});




}
/// @nodoc
class __$VariationOutCopyWithImpl<$Res>
    implements _$VariationOutCopyWith<$Res> {
  __$VariationOutCopyWithImpl(this._self, this._then);

  final _VariationOut _self;
  final $Res Function(_VariationOut) _then;

/// Create a copy of VariationOut
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? variationType = null,Object? stock = null,Object? searchTags = freezed,}) {
  return _then(_VariationOut(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,variationType: null == variationType ? _self.variationType : variationType // ignore: cast_nullable_to_non_nullable
as String,stock: null == stock ? _self.stock : stock // ignore: cast_nullable_to_non_nullable
as int,searchTags: freezed == searchTags ? _self.searchTags : searchTags // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
