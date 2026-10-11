/// Una página de `GET /sync/catalog` tal cual la devuelve el servidor.
///
/// Los `products`/`categories` llegan como maps crudos: se aplican a la base
/// local dentro de una transacción (reemplazo completo de los hijos de cada
/// producto) en vez de pasar por `ProductDetailOut.fromJson`, para no perder
/// campos futuros ni depender de la validación estricta de freezed.
class SyncPage {
  /// `server_time` de ESTA página, tal cual el string del servidor.
  final String serverTime;
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> categories;
  final List<int> deletedProducts;
  final List<int> deletedVariations;
  final List<int> deletedCategories;
  final bool hasMore;

  const SyncPage({
    required this.serverTime,
    required this.products,
    required this.categories,
    required this.deletedProducts,
    required this.deletedVariations,
    required this.deletedCategories,
    required this.hasMore,
  });

  factory SyncPage.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> maps(dynamic value) =>
        (value as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
    List<int> ids(dynamic value) =>
        (value as List<dynamic>? ?? const []).cast<int>();

    return SyncPage(
      // Se conserva el string crudo: se reenvía como parámetro `since` sin
      // reinterpretar (evita pérdidas de precisión al parsear/serializar).
      serverTime: json['server_time']?.toString() ?? '',
      products: maps(json['products']),
      categories: maps(json['categories']),
      deletedProducts: ids(json['deleted_products']),
      deletedVariations: ids(json['deleted_variations']),
      deletedCategories: ids(json['deleted_categories']),
      hasMore: json['has_more'] as bool? ?? false,
    );
  }

  /// true si la página trae cambios de contenido (no solo un cursor nuevo).
  bool get hasContent =>
      products.isNotEmpty ||
      categories.isNotEmpty ||
      deletedProducts.isNotEmpty ||
      deletedVariations.isNotEmpty ||
      deletedCategories.isNotEmpty;
}
