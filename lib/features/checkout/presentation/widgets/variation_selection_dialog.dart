import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/images/catalog_image.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../catalog/domain/product_model.dart';
import 'product_image_viewer.dart';

/// Diálogo de selección de variante con el lenguaje visual de la cuadrícula
/// del catálogo:
///
/// - Cuadro cuadrado con la foto propia de la variante (si está asociada en
///   el server) o un placeholder cuando no la tiene. El tap en el cuadro
///   abre el visor de imágenes a pantalla completa (con la galería del
///   producto de respaldo si la variante no tiene foto).
/// - Tocar el resto de la fila agrega la variante al carrito: el antiguo
///   botón "Agregar" por fila se retiró. Las agotadas no se pueden agregar
///   (nombre apagado, sin acción) y llevan el mismo badge rojo "AGOTADO"
///   que sobre la foto en la cuadrícula.
class VariationSelectionDialog extends ConsumerWidget {
  final ProductDetailOut product;
  final Function(VariationOut selectedVariation) onVariationSelected;

  const VariationSelectionDialog({
    super.key,
    required this.product,
    required this.onVariationSelected,
  });

  /// Origen del server (misma fórmula que la tarjeta del catálogo) para
  /// resolver rutas relativas de las fotos.
  static String _serverBaseUrl(String dioBaseUrl) {
    final uri = Uri.parse(dioBaseUrl);
    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  }

  static String _absolute(String path, String baseUrl) =>
      path.startsWith('http') ? path : '$baseUrl$path';

  /// Fotos de la variante (las asociadas a su id); vacío si no tiene.
  List<ProductImageOut> _variantImages(VariationOut variation) =>
      product.images
          .where((img) => img.variationIds.contains(variation.id))
          .toList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseUrl = _serverBaseUrl(
        ref.read(dioClientProvider).dio.options.baseUrl);

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            product.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Selecciona una variante (Precio: \$${product.finalPrice})',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: product.variations.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) =>
              _buildRow(context, product.variations[index], baseUrl),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }

  Widget _buildRow(
      BuildContext context, VariationOut variation, String baseUrl) {
    final bool hasStock = variation.stock > 0;
    final variantImages = _variantImages(variation);

    // Cuadrado 56×56: foto de la variante (miniatura si existe) o
    // placeholder si no tiene ninguna asociada.
    final Widget square = variantImages.isEmpty
        ? _placeholderSquare()
        : CatalogImage(
            imageUrl: _absolute(
                (variantImages.first.thumbnailUrl?.isNotEmpty ?? false)
                    ? variantImages.first.thumbnailUrl!
                    : variantImages.first.imageUrl,
                baseUrl),
            fit: BoxFit.cover,
            memCacheWidth: 112,
            placeholder: (_, _) => _placeholderSquare(),
            errorWidget: (_, _, _) => _placeholderSquare(),
          );

    // El tap del cuadro abre el visor: las fotos de la variante o, si no
    // tiene, la galería general del producto.
    void openViewer() {
      final urls = variantImages.isNotEmpty
          ? [
              for (final img in variantImages)
                _absolute(img.imageUrl, baseUrl),
            ]
          : productImageUrls(product, baseUrl);
      ProductImageViewer.show(context, title: product.name, urls: urls);
    }

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      // Agotadas: sin acción (el visor del cuadro sigue disponible).
      onTap: hasStock
          ? () {
              Navigator.of(context).pop();
              onVariationSelected(variation);
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // El cuadro tiene su propio gesto (gana al de la fila) y abre
            // el visor: no agrega.
            Tooltip(
              message: 'Ver foto',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: openViewer,
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: Stack(
                      clipBehavior: Clip.antiAlias,
                      children: [
                        Positioned.fill(child: square),
                        if (!hasStock)
                          const Positioned(
                              top: 4, left: 4, child: _AgotadoBadge()),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    variation.variationType,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: hasStock ? Colors.black87 : Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasStock
                        ? 'Stock disponible: ${variation.stock}'
                        : 'Agotado',
                    style: TextStyle(
                      color: hasStock ? Colors.green[700] : Colors.red[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Sustituto visual del botón retirado: la fila es clicable.
            if (hasStock)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.add_circle_outline,
                  size: 22,
                  color: Colors.indigo,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderSquare() => Container(
        color: Colors.grey[200],
        alignment: Alignment.center,
        child: Icon(Icons.image_outlined, size: 28, color: Colors.grey[500]),
      );
}

/// Mismo badge rojo "AGOTADO" que sobre la foto en la cuadrícula del POS.
class _AgotadoBadge extends StatelessWidget {
  const _AgotadoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'AGOTADO',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
