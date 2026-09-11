import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../catalog/presentation/providers/catalog_provider.dart';
import '../data/models/create_order_dto.dart';
import '../data/orders_repository.dart';
import '../data/models/exchange_rate.dart';
import 'providers/cart_provider.dart';
import 'providers/search_provider.dart';
import 'widgets/search_input_bar.dart';
import 'widgets/variation_selection_dialog.dart';
import 'widgets/cart_panel.dart';
import 'checkout_screen.dart';

final selectedCategoryProvider = StateProvider<dynamic>((ref) => null);

/// Width below which the layout switches to a single-column, phone-style
/// layout with the cart accessible via a bottom sheet.
const double _kWideBreakpoint = 900;

class PosScreen extends ConsumerWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _kWideBreakpoint;

        return Scaffold(
          appBar: AppBar(
            title: const Text('NaaviShop POS'),
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            actions: [
              if (cartItems.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  onPressed: cartNotifier.clear,
                  tooltip: 'Vaciar Carrito',
                ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                tooltip: 'Cerrar Sesión',
                onPressed: () => _confirmLogout(context, ref),
              ),
            ],
          ),
          body: isWide
              ? _WideLayout()
              : _NarrowLayout(),
          bottomNavigationBar:
              isWide ? null : const _MobileCartBar(),
        );
      },
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text(
            '¿Estás seguro de que deseas salir del sistema POS?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(authProvider.notifier).logout();
    }
  }
}

// ─────────────────────────────────────────────────────────────
// WIDE LAYOUT (tablet / desktop / WebView wide)
// ─────────────────────────────────────────────────────────────
class _WideLayout extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exchangeRateAsync = ref.watch(currentExchangeRateProvider);
    final currentRate = exchangeRateAsync.when(
      data: (r) => r.rate,
      loading: () => null,
      error: (_, _) => null,
    );

    return Row(
      children: [
        // Product browser takes all remaining space
        const Expanded(
          child: ColoredBox(
            color: Color(0xFFF5F5F5),
            child: _ProductBrowser(padding: EdgeInsets.all(16)),
          ),
        ),
        // Fixed-width cart panel
        Container(
          width: 380,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(left: BorderSide(color: Colors.black12)),
          ),
          padding: const EdgeInsets.all(16),
          child: CartPanel(
            currentRate: currentRate,
            onCheckout: () => openCheckoutModal(context, ref, currentRate),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// NARROW LAYOUT (phones)
// ─────────────────────────────────────────────────────────────
class _NarrowLayout extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ColoredBox(
      color: Color(0xFFF5F5F5),
      child: _ProductBrowser(padding: EdgeInsets.all(12)),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Persistent cart bar at the bottom of narrow layout
// ─────────────────────────────────────────────────────────────
class _MobileCartBar extends ConsumerWidget {
  const _MobileCartBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final exchangeRateAsync = ref.watch(currentExchangeRateProvider);
    final currentRate = exchangeRateAsync.when(
      data: (r) => r.rate,
      loading: () => null,
      error: (_, _) => null,
    );

    if (cartItems.isEmpty) return const SizedBox.shrink();

    final totalUsd = cartNotifier.subtotal;
    final totalBs = currentRate != null ? totalUsd * currentRate : null;
    final itemCount =
        cartItems.fold<int>(0, (sum, i) => sum + i.quantity);

    return Material(
      color: Colors.indigo,
      child: InkWell(
        onTap: () => _openCartSheet(context, ref, currentRate),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      Icons.shopping_cart,
                      color: Colors.white,
                      size: 28,
                    ),
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          '$itemCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '\$${totalUsd.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (totalBs != null)
                        Text(
                          'Bs. ${totalBs.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_up,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openCartSheet(
    BuildContext context,
    WidgetRef ref,
    double? currentRate,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.85,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                // drag handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: CartPanel(
                    currentRate: currentRate,
                    onCheckout: () {
                      Navigator.of(sheetContext).pop();
                      // Open checkout once the sheet finishes popping.
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        openCheckoutModal(context, ref, currentRate);
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Product browser — search bar + category + responsive grid
// ─────────────────────────────────────────────────────────────
class _ProductBrowser extends ConsumerWidget {
  final EdgeInsets padding;
  const _ProductBrowser({required this.padding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: padding,
      child: Column(
        children: [
          const _TopBar(),
          const SizedBox(height: 12),
          Expanded(child: _ProductGrid()),
        ],
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final isNarrow = MediaQuery.sizeOf(context).width < 600;

    return Row(
      children: [
        const Expanded(child: SearchInputBar()),
        const SizedBox(width: 8),
        if (isNarrow)
          IconButton.filledTonal(
            tooltip: selectedCategory?.name ?? 'Categorías',
            icon: Badge(
              isLabelVisible: selectedCategory != null,
              child: const Icon(Icons.category),
            ),
            style: IconButton.styleFrom(
              backgroundColor: selectedCategory != null
                  ? Colors.indigo
                  : Colors.white,
              foregroundColor: selectedCategory != null
                  ? Colors.white
                  : Colors.indigo,
              minimumSize: const Size(48, 48),
            ),
            onPressed: () => openCategoriesModal(context, ref),
          )
        else
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              backgroundColor: selectedCategory != null
                  ? Colors.indigo
                  : Colors.white,
              foregroundColor: selectedCategory != null
                  ? Colors.white
                  : Colors.indigo,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Colors.indigo),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.category),
            label: Text(
              selectedCategory != null
                  ? selectedCategory.name
                  : 'Categorías',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () => openCategoriesModal(context, ref),
          ),
        if (selectedCategory != null && !isNarrow) ...[
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.grey),
            tooltip: 'Quitar filtro de categoría',
            onPressed: () {
              ref.read(selectedCategoryProvider.notifier).state = null;
            },
          ),
        ],
      ],
    );
  }
}

class _ProductGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final exchangeRateAsync = ref.watch(currentExchangeRateProvider);
    final dioClient = ref.watch(dioClientProvider);

    final fullUri = Uri.parse(dioClient.dio.options.baseUrl);
    final serverBaseUrl =
        '${fullUri.scheme}://${fullUri.host}${fullUri.hasPort ? ':${fullUri.port}' : ''}';

    final currentRate = exchangeRateAsync.when(
      data: (r) => r.rate,
      loading: () => null,
      error: (_, _) => null,
    );

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error al cargar productos: $err',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => ref.refresh(productsProvider),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
      data: (products) {
        final query = searchQuery.toLowerCase().trim();
        final filtered = products.where((product) {
          bool matchesQuery = true;
          if (query.isNotEmpty) {
            final matchesName =
                product.name.toLowerCase().contains(query);
            final matchesVariation = product.variations.any(
              (v) => v.variationType.toLowerCase().contains(query),
            );
            matchesQuery = matchesName || matchesVariation;
          }

          bool matchesCategory = true;
          if (selectedCategory != null) {
            matchesCategory = product.categories.any(
              (c) => c.id == selectedCategory.id,
            );
          }

          return matchesQuery && matchesCategory;
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                query.isEmpty && selectedCategory == null
                    ? 'No hay productos disponibles.'
                    : 'No se encontraron productos con los filtros aplicados.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          );
        }

        return GridView.builder(
          padding: EdgeInsets.zero,
          // Auto-computes column count from available width. Cards never
          // get wider than ~200dp, so on a 360dp phone you get 2 columns;
          // on a 1200dp desktop you get ~6, without a single manual
          // breakpoint.
          gridDelegate:
              const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            childAspectRatio: 0.72,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final product = filtered[index];
            final double priceUsd =
                (product.finalPrice as num).toDouble();
            final double? priceBs = currentRate != null
                ? priceUsd * currentRate
                : null;

            return Card(
              elevation: 2,
              clipBehavior: Clip.antiAlias,
              margin: EdgeInsets.zero,
              child: InkWell(
                onTap: () => _onProductTap(context, ref, product),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ProductImageCarousel(
                        product: product,
                        baseUrl: serverBaseUrl,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '\$${priceUsd.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            priceBs != null
                                ? 'Bs. ${priceBs.toStringAsFixed(2)}'
                                : 'Bs. --',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _onProductTap(BuildContext context, WidgetRef ref, dynamic product) {
    final cartNotifier = ref.read(cartProvider.notifier);

    if (product.variations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Este producto no tiene variantes registradas.'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => VariationSelectionDialog(
        product: product,
        onVariationSelected: (selectedVariation) {
          cartNotifier.addProduct(
            variationId: selectedVariation.id,
            name:
                '${product.name} - ${selectedVariation.variationType}',
            price: product.finalPrice,
            maxStock: selectedVariation.stock,
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Categories bottom sheet
// ─────────────────────────────────────────────────────────────
void openCategoriesModal(BuildContext context, WidgetRef ref) {
  final selectedCategory = ref.read(selectedCategoryProvider);
  final categoriesAsync = ref.read(categoriesProvider);

  showModalBottomSheet(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (modalContext) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Categorías',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (selectedCategory != null)
                  TextButton.icon(
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Limpiar filtro'),
                    onPressed: () {
                      ref
                          .read(selectedCategoryProvider.notifier)
                          .state = null;
                      Navigator.pop(modalContext);
                    },
                  ),
              ],
            ),
            const Divider(),
            Expanded(
              child: categoriesAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (err, _) => Center(
                  child: Text(
                    'Error al cargar categorías: $err',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                data: (categories) {
                  if (categories.isEmpty) {
                    return const Center(
                      child: Text('No hay categorías disponibles.'),
                    );
                  }
                  return ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final isSelected =
                          selectedCategory?.id == category.id;

                      return ListTile(
                        title: Text(category.name),
                        selected: isSelected,
                        selectedTileColor: Colors.indigo.shade50,
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.indigo,
                              )
                            : null,
                        onTap: () {
                          ref
                              .read(selectedCategoryProvider.notifier)
                              .state = category;
                          Navigator.pop(modalContext);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────
// Checkout bottom sheet (shared by both layouts)
// ─────────────────────────────────────────────────────────────
void openCheckoutModal(
  BuildContext context,
  WidgetRef ref,
  double? currentRate,
) {
  final cartItems = ref.read(cartProvider);
  final cartNotifier = ref.read(cartProvider.notifier);
  if (cartItems.isEmpty) return;

  final orderItems = cartItems
      .map((item) => OrderItemIn(
            variationId: item.variationId,
            quantity: item.quantity,
          ))
      .toList();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (dialogContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(dialogContext).viewInsets.bottom,
        ),
        child: CheckoutScreen(
          cartItems: orderItems,
          subtotal: cartNotifier.subtotal,
          currentRate: currentRate,
          onSubmitOrder: (orderPayload) async {
            try {
              final ordersRepo = ref.read(ordersRepositoryProvider);
              final result =
                  await ordersRepo.createOrder(orderPayload.toJson());

              if (context.mounted) {
                Navigator.of(dialogContext).pop();
                cartNotifier.clear();
                ref.invalidate(productsProvider);
                final orderId = result['id'];
                final totalBs = result['total_bs'];

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '¡Orden #$orderId creada exitosamente! Total: Bs. ${totalBs ?? ''}',
                    ),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      e.toString().replaceAll('Exception: ', ''),
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        ),
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────
// Product image carousel (unchanged, kept here for brevity)
// ─────────────────────────────────────────────────────────────
class ProductImageCarousel extends StatefulWidget {
  final dynamic product;
  final String baseUrl;

  const ProductImageCarousel({
    super.key,
    required this.product,
    required this.baseUrl,
  });

  @override
  State<ProductImageCarousel> createState() =>
      _ProductImageCarouselState();
}

class _ProductImageCarouselState extends State<ProductImageCarousel> {
  late final PageController _pageController;
  int _currentIndex = 0;

  List<String> _getImageUrls() {
    final List<String> urls = [];
    if (widget.product.images != null &&
        widget.product.images.isNotEmpty) {
      for (final img in widget.product.images) {
        final path = img.imageUrl ?? img.url;
        if (path != null) {
          urls.add(
            path.startsWith('http') ? path : '${widget.baseUrl}$path',
          );
        }
      }
    }
    if (urls.isEmpty) {
      final mainUrl = widget.product.getMainImageUrl(widget.baseUrl);
      if (mainUrl != null) urls.add(mainUrl);
    }
    return urls;
  }

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

  @override
  Widget build(BuildContext context) {
    final imageUrls = _getImageUrls();

    if (imageUrls.isEmpty) {
      return Container(
        color: Colors.indigo.shade50,
        child: const Center(
          child: Icon(
            Icons.inventory_2,
            color: Colors.indigo,
            size: 40,
          ),
        ),
      );
    }

    return Container(
      color: Colors.indigo.shade50,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: imageUrls.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              return Image.network(
                imageUrls[index],
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(
                    Icons.image_not_supported,
                    color: Colors.grey,
                  ),
                ),
              );
            },
          ),
          if (imageUrls.length > 1) ...[
            if (_currentIndex > 0)
              Positioned(
                left: 4,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Material(
                    color: Colors.black38,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      icon: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                  ),
                ),
              ),
            if (_currentIndex < imageUrls.length - 1)
              Positioned(
                right: 4,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Material(
                    color: Colors.black38,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      icon: const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      onPressed: () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}