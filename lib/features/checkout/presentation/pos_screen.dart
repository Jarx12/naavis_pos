import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../catalog/presentation/providers/catalog_provider.dart';
import '../data/models/create_order_dto.dart';
import '../data/orders_repository.dart';
import 'checkout_screen.dart';
import 'providers/cart_provider.dart';
import 'widgets/variation_selection_dialog.dart';

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String value) => state = value;
  void clear() => state = '';
}

final searchQueryProvider =
    NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

// Provider para gestionar la categoría seleccionada actualmente
final selectedCategoryProvider = StateProvider<dynamic>((ref) => null);

class PosScreen extends ConsumerWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final cartItems = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final searchQuery = ref.watch(searchQueryProvider);

    // Lectura del cliente Dio para construir la URL base de imágenes
    final dioClient = ref.watch(dioClientProvider);
    final fullUri = Uri.parse(dioClient.dio.options.baseUrl);
    final serverBaseUrl =
        '${fullUri.scheme}://${fullUri.host}${fullUri.hasPort ? ':${fullUri.port}' : ''}';

    // Abrir Modal de Categorías
    void openCategoriesModal() {
      showModalBottomSheet(
        context: context,
        useSafeArea: true,
        builder: (modalContext) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Categorías',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (selectedCategory != null)
                      TextButton.icon(
                        icon: const Icon(Icons.clear, size: 18),
                        label: const Text('Limpiar filtro'),
                        onPressed: () {
                          ref.read(selectedCategoryProvider.notifier).state =
                              null;
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
                    error: (err, stack) => Center(
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
                                ? const Icon(Icons.check_circle,
                                    color: Colors.indigo)
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

    // Abrir Modal de Checkout para Cobrar
    void openCheckoutModal() {
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
                            e.toString().replaceAll('Exception: ', '')),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('NaaviShop POS'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: cartItems.isEmpty ? null : () => cartNotifier.clear(),
            tooltip: 'Vaciar Carrito',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Cerrar Sesión',
            onPressed: () async {
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
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Salir'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await ref.read(authProvider.notifier).logout();
              }
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // 1. Grid de Productos
          Expanded(
            flex: 7,
            child: Container(
              color: Colors.grey[100],
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (value) {
                            ref
                                .read(searchQueryProvider.notifier)
                                .update(value);
                          },
                          decoration: InputDecoration(
                            hintText: 'Buscar producto por nombre o variante...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      ref
                                          .read(searchQueryProvider.notifier)
                                          .clear();
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
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
                        onPressed: openCategoriesModal,
                      ),
                      if (selectedCategory != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.grey),
                          tooltip: 'Quitar filtro de categoría',
                          onPressed: () {
                            ref.read(selectedCategoryProvider.notifier).state =
                                null;
                          },
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: productsAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      error: (err, stack) => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Error al cargar productos: $err',
                              style: const TextStyle(color: Colors.red),
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
                        final filteredProducts = products.where((product) {
                          // 1. Text Search Filter
                          bool matchesQuery = true;
                          if (query.isNotEmpty) {
                            final matchesName = product.name.toLowerCase().contains(query);
                            final matchesVariation = product.variations.any(
                              (variation) => variation.variationType.toLowerCase().contains(query),
                            );
                            matchesQuery = matchesName || matchesVariation;
                          }

                          // 2. Category List Filter
                          bool matchesCategory = true;
                          if (selectedCategory != null) {
                            matchesCategory = product.categories.any(
                              (category) => category.id == selectedCategory.id,
                            );
                          }

                          return matchesQuery && matchesCategory;
                        }).toList();

                        if (filteredProducts.isEmpty) {
                          return Center(
                            child: Text(
                              query.isEmpty && selectedCategory == null
                                  ? 'No hay productos disponibles.'
                                  : 'No se encontraron productos con los filtros aplicados.',
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.grey),
                            ),
                          );
                        }

                        return GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            childAspectRatio: 0.8,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = filteredProducts[index];

                            return Card(
                              elevation: 2,
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () {
                                  if (product.variations.isNotEmpty) {
                                    showDialog(
                                      context: context,
                                      builder: (_) => VariationSelectionDialog(
                                        product: product,
                                        onVariationSelected:
                                            (selectedVariation) {
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
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Este producto no tiene variantes registradas.'),
                                      ),
                                    );
                                  }
                                },
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                            '\$${product.finalPrice.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
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
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Carrito Interactivo Lateral
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Orden Actual',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  Expanded(
                    child: cartItems.isEmpty
                        ? const Center(
                            child: Text(
                              'El carrito está vacío',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: cartItems.length,
                            itemBuilder: (context, index) {
                              final item = cartItems[index];
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  item.productName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '\$${item.price.toStringAsFixed(2)} x ${item.quantity}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                          Icons.remove_circle_outline,
                                          size: 20),
                                      onPressed: () => cartNotifier
                                          .updateQuantity(
                                              item.variationId, -1,
                                              maxStock: item.maxStock),
                                    ),
                                    Text('${item.quantity}'),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.add_circle_outline,
                                          size: 20),
                                      onPressed: () => cartNotifier
                                          .updateQuantity(
                                              item.variationId, 1,
                                              maxStock: item.maxStock),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const Divider(),
                  _buildTotalSection(subtotal: cartNotifier.subtotal),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cartItems.isEmpty
                            ? Colors.grey
                            : Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.point_of_sale),
                      label: const Text(
                        'PROCESAR COBRO',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      onPressed:
                          cartItems.isEmpty ? null : openCheckoutModal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSection({required double subtotal}) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('TOTAL USD:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              '\$${subtotal.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo),
            ),
          ],
        ),
      ],
    );
  }
}

class ProductImageCarousel extends StatefulWidget {
  final dynamic product;
  final String baseUrl;

  const ProductImageCarousel({
    super.key,
    required this.product,
    required this.baseUrl,
  });

  @override
  State<ProductImageCarousel> createState() => _ProductImageCarouselState();
}

class _ProductImageCarouselState extends State<ProductImageCarousel> {
  late final PageController _pageController;
  int _currentIndex = 0;

  List<String> _getImageUrls() {
    final List<String> urls = [];
    if (widget.product.images != null && widget.product.images.isNotEmpty) {
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
          child: Icon(Icons.inventory_2, color: Colors.indigo, size: 40),
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
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return Image.network(
                imageUrls[index],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.image_not_supported, color: Colors.grey),
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
                      icon: const Icon(Icons.chevron_left,
                          color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
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
                      icon: const Icon(Icons.chevron_right,
                          color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
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
            Positioned(
              bottom: 4,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  imageUrls.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentIndex == index
                          ? Colors.white
                          : Colors.white54,
                    ),
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