import 'package:flutter/material.dart';

import '../../../../core/images/catalog_image.dart';

/// URLs completas de las imágenes de un producto (acepta `ProductDetailOut`
/// o cualquier shape dinámico con `images`/`getMainImageUrl`).
///
/// Misma regla que el carrusel de la tarjeta: las rutas absolutas se usan
/// tal cual y las relativas se arman contra [baseUrl]; si no hay URLs se
/// cae a la imagen principal del producto.
List<String> productImageUrls(dynamic product, String baseUrl) {
  final List<String> urls = [];
  final dynamic images = product.images;
  if (images != null && images.isNotEmpty) {
    for (final dynamic img in images) {
      final dynamic path = img.imageUrl;
      if (path != null) {
        final String url = path.toString();
        if (url.isNotEmpty) {
          urls.add(url.startsWith('http') ? url : '$baseUrl$url');
        }
      }
    }
  }
  if (urls.isEmpty) {
    final String? mainUrl = product.getMainImageUrl(baseUrl);
    if (mainUrl != null && mainUrl.isNotEmpty) urls.add(mainUrl);
  }
  return urls;
}

/// Visor de imágenes a pantalla casi completa: pinch para zoom, arrastre
/// para moverse y `PageView` si el producto tiene varias fotos.
class ProductImageViewer extends StatefulWidget {
  final String title;
  final List<String> imageUrls;

  const ProductImageViewer({
    super.key,
    required this.title,
    required this.imageUrls,
  });

  /// Abre el visor (no hace nada si no hay imágenes).
  ///
  /// Se cierra con el botón ✕, tocando la imagen (sin arrastrar) o
  /// haciendo clic fuera del diálogo (barrera).
  static Future<void> show(
    BuildContext context, {
    required String title,
    required List<String> urls,
  }) {
    if (urls.isEmpty) return Future<void>.value();
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => ProductImageViewer(title: title, imageUrls: urls),
    );
  }

  @override
  State<ProductImageViewer> createState() => _ProductImageViewerState();
}

class _ProductImageViewerState extends State<ProductImageViewer> {
  late final PageController _pageController;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int target) {
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasMany = widget.imageUrls.length > 1;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      backgroundColor: const Color(0xFF141414),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Cabecera ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white24),
          // ── Imagen(es) con zoom ──────────────────────────────────
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Tocar/clicar sin arrastrar cierra el visor; el arrastre
                // (swipe del PageView, pan/zoom del InteractiveViewer) lo
                // siguen ganando los reconocedores interiores.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: widget.imageUrls.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, index) {
                      return InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 5,
                        child: SizedBox.expand(
                          child: CatalogImage(
                            imageUrl: widget.imageUrls[index],
                            fit: BoxFit.contain,
                            // Sin memCacheWidth: el visor necesita el original
                            // a tamaño completo para que el zoom salve calidad.
                            placeholder: (_, _) => const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white70,
                              ),
                            ),
                            errorWidget: (_, _, _) => const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.broken_image,
                                      color: Colors.white54, size: 48),
                                  SizedBox(height: 8),
                                  Text(
                                    'No se pudo cargar la imagen',
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Flechas: cambian de imagen con clic (escritorio) o tap
                // (móvil), sin necesidad de arrastrar.
                if (hasMany && _index > 0)
                  Positioned(
                    left: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _NavButton(
                        icon: Icons.chevron_left,
                        tooltip: 'Imagen anterior',
                        onTap: () => _goTo(_index - 1),
                      ),
                    ),
                  ),
                if (hasMany && _index < widget.imageUrls.length - 1)
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _NavButton(
                        icon: Icons.chevron_right,
                        tooltip: 'Imagen siguiente',
                        onTap: () => _goTo(_index + 1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // ── Indicador de páginas ─────────────────────────────────
          if (hasMany)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.imageUrls.length; i++)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            i == _index ? Colors.white : Colors.white24,
                      ),
                    ),
                ],
              ),
            )
          else
            const SizedBox(height: 10),
        ],
      ),
    );
  }
}

/// Botón circular de navegación del visor (flechas ←/→), mismo lenguaje
/// visual que el carrusel de la tarjeta.
class _NavButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black38,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: Colors.white, size: 32),
        onPressed: onTap,
      ),
    );
  }
}
