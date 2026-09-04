import 'package:freezed_annotation/freezed_annotation.dart';

part 'category_model.freezed.dart';
part 'category_model.g.dart';

@freezed
abstract class CategoryOut with _$CategoryOut {
  const factory CategoryOut({
    required int id,
    required String name,
  }) = _CategoryOut;

  factory CategoryOut.fromJson(Map<String, dynamic> json) =>
      _$CategoryOutFromJson(json);
}