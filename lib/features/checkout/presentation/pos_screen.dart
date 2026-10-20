import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/images/catalog_image.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/utils/fuzzy_match.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../catalog/data/local_catalog_repository.dart';
import '../../catalog/presentation/providers/catalog_provider.dart';
import '../../sync/data/sync_service.dart';
import '../data/models/create_order_dto.dart';
import '../data/models/exchange_rate.dart';
import '../data/outbox_service.dart';
import 'providers/cart_provider.dart';
import 'providers/display_options.dart';
import 'providers/search_provider.dart';
import 'widgets/order_conflict_dialog.dart';
import 'widgets/outbox_sheet.dart';
import 'widgets/product_image_viewer.dart';
import 'widgets/search_input_bar.dart';
import 'widgets/variation_selection_dialog.dart';
import 'widgets/cart_panel.dart';
import 'checkout_screen.dart';

final selectedCategoryProvider = StateProvider<dynamic>((ref) => null);

/// Width below which the layout switches to a single-column, phone-style
/// layout with the cart accessible via a bottom sheet.
const double _kWideBreakpoint = 900;

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  /// Spinner del botón de refresh (la sync puede tardar en el seed).
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    // Órdenes que quedaron pendientes de una sesión anterior: probar el
    // envío apenas entra el POS (si no hay red, el timer sigue solo).
    Future.microtask(() => ref.read(outboxServiceProvider).flush());
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final displayOptions = ref.watch(displayOptionsProvider);
    final outboxRows = ref.watch(outboxRowsProvider).value ?? const [];
    final attentionCount = outboxRows.where((r) => r.needsAttention).length;

    // Reacciones a eventos de la cola disparados por los reenvíos de
    // fondo (timer de reintentos / vuelta de la red).
    ref.listen(outboxEventProvider, (previous, next) {
      final event = next;
      if (event == null || event.seq == previous?.seq) return;
      _handleOutboxEvent(event);
    });

    // Al volver la red: sacar la cola y refrescar el catálogo.
    ref.listen(connectivityProvider, (previous, next) {
      if (next == ConnectivityState.online &&
          previous != ConnectivityState.online) {
        ref.read(outboxServiceProvider).flush();
        _backgroundSync();
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _kWideBreakpoint;

        return Scaffold(
          appBar: AppBar(
            title: const Text('NSHOP POS'),
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: _refreshing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh),
                tooltip: 'Actualizar catálogo',
                onPressed:
                    _refreshing ? null : () => _refreshCatalog(context),
              ),
              IconButton(
                icon: Badge(
                  isLabelVisible: outboxRows.isNotEmpty,
                  label: Text('${outboxRows.length}'),
                  backgroundColor:
                      attentionCount > 0 ? Colors.red : Colors.orange,
                  child: const Icon(Icons.pending_actions),
                ),
                tooltip: 'Órdenes fuera de línea',
                onPressed: () => OutboxSheet.show(context),
              ),
              IconButton(
                icon: Badge(
                  isLabelVisible: displayOptions.showInvisible ||
                      displayOptions.showOutOfStock,
                  child: const Icon(Icons.tune),
                ),
                tooltip: 'Opciones de visualización',
                onPressed: () => _showDisplayOptionsDialog(context),
              ),
              if (cartItems.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  onPressed: cartNotifier.clear,
                  tooltip: 'Vaciar Carrito',
                ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                tooltip: 'Cerrar Sesión',
                onPressed: () => _confirmLogout(context),
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


  /// Sincroniza delta + tasa y refresca la UI. El catálogo local sirve
  /// aunque la falle: en ese caso se avisa y se siguen mostrando los
  /// datos guardados en este equipo.
  Future<void> _refreshCatalog(BuildContext context,
      {String okMessage = 'Catálogo actualizado'}) async {
    setState(() => _refreshing = true);
    try {
      final result = await ref.read(syncServiceProvider).sync();
      if (!mounted) return;

      ref
        ..invalidate(productsProvider)
        ..invalidate(categoriesProvider)
        ..invalidate(currentExchangeRateProvider);

      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      if (result.ok) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(okMessage),
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (result.offline) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
                'Sin conexión: se muestran los datos guardados localmente.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        messenger.showSnackBar(SnackBar(
          content: Text(result.message ?? 'No se pudo actualizar.'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  /// Re-seed manual (Configuración): borra el cursor de sync y descarga el
  /// catálogo COMPLETO. No se borra la caché local: si no hay red se
  /// conservan los datos y el cursor queda limpio, así el próximo intento
  /// (o el arranque) pide el seed completo.
  Future<void> _reseedCatalog() async {
    await ref.read(localCatalogProvider).clearSyncState();
    if (!mounted) return;
    await _refreshCatalog(context,
        okMessage: 'Catálogo actualizado');
  }

  /// Delta en segundo plano; refresca la grilla cuando termine.
  void _backgroundSync() {
    ref.read(syncServiceProvider).sync().then((result) {
      if (mounted && result.ok) {
        ref
          ..invalidate(productsProvider)
          ..invalidate(categoriesProvider);
      }
    });
  }

  /// Reacciona a los eventos que la cola emite durante los reenvíos de
  /// fondo (los envíos desde el checkout se manejan ahí mismo).
  Future<void> _handleOutboxEvent(OutboxEvent event) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    switch (event.kind) {
      case OutboxEventKind.sent:
        _backgroundSync();
        messenger.showSnackBar(SnackBar(
          content: Text(
              'Orden #${event.orderId ?? ''} enviada. Total: Bs. ${event.totalBs ?? ''}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ));
      case OutboxEventKind.attention:
        // Rechazo de negocio detectado en un reenvío de fondo (típico:
        // el stock cambió mientras la orden estaba encolada).
        _backgroundSync();
        if (event.errorCode == 'INSUFFICIENT_STOCK') {
          await OrderConflictDialog.show(context, event.localId);
        } else {
          messenger.showSnackBar(SnackBar(
            content: Text(
                '${event.errorMessage ?? 'Orden rechazada por el servidor.'} '
                'Ábrela desde "Órdenes fuera de línea" para editarla o '
                'descartarla.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ));
        }
      case OutboxEventKind.queued:
        // Solo informativo; el checkout ya muestra su propio aviso.
        break;
    }
  }

  /// Configuración del POS: switches de visualización (persistidos) y
  /// mantenimiento de datos (re-seed del catálogo).
  void _showDisplayOptionsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setLocal) {
            final options = ref.read(displayOptionsProvider);
            final notifier = ref.read(displayOptionsProvider.notifier);
            return AlertDialog(
              title: const Text('Configuración'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Productos ocultos'),
                    subtitle: const Text(
                        'No visibles en la tienda (badge "OCULTO")'),
                    value: options.showInvisible,
                    onChanged: (v) {
                      notifier.setShowInvisible(v);
                      setLocal(() {});
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Productos agotados'),
                    subtitle: const Text(
                        'Sin stock (badge "AGOTADO")'),
                    value: options.showOutOfStock,
                    onChanged: (v) {
                      notifier.setShowOutOfStock(v);
                      setLocal(() {});
                    },
                  ),
                  const Divider(height: 24),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Datos',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Descarga el catálogo completo desde el servidor. '
                      'Usalo en caso de problemas con la actualización '
                      'del inventario o las fotos.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: dialogContext,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Limpiar Catalogo'),
                            content: const Text(
                                'Se volverá a descargar el catálogo '
                                'desde el servidor '
                                '¿Continuar?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancelar'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Re-seed'),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true || !mounted) return;
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        await _reseedCatalog();
                      },
                      icon: const Icon(Icons.cloud_sync_outlined, size: 18),
                      label: const Text('Descarga completa del catálogo'),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Listo'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text(
            '¿Está seguro de que desea cerrar sesión?'),
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
    final displayOptions = ref.watch(displayOptionsProvider);
    final connectivity = ref.watch(connectivityProvider);
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
          // Filtros de visualización (togglables): invisibles / agotados.
          // Con ambos apagados se replica el `only_visible` del server.
          final hasStock = product.variations.any((v) => v.stock > 0);
          if (!displayOptions.showInvisible && !product.isVisible) {
            return false;
          }
          if (!displayOptions.showOutOfStock && !hasStock) return false;

          bool matchesQuery = true;
          if (query.isNotEmpty) {
            // Búsqueda difusa: la subcadena exacta tiene prioridad y,
            // si no pega, se toleran hasta 1-2 typos según el largo de
            // la consulta (los códigos numéricos quedan exactos).
            final matchesName = fuzzyMatch(query, product.name);
            final matchesVariation = product.variations.any(
              (v) => fuzzyMatch(query, v.variationType),
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
          final offline =
              connectivity == ConnectivityState.offline;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                offline && products.isEmpty
                    ? 'Sin conexión y sin productos guardados en este '
                        'dispositivo. Conéctate a la red para descargar el '
                        'catálogo.'
                    : query.isEmpty && selectedCategory == null
                        ? (products.isEmpty
                            ? 'No hay productos disponibles.'
                            : 'Todos los productos están ocultos por los '
                                'filtros de visualización.')
                        : 'No se encontraron productos con los filtros '
                            'aplicados.',
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
            final hasStock = product.variations.any((v) => v.stock > 0);
            final imageUrls = productImageUrls(product, serverBaseUrl);

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
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ProductImageCarousel(
                            product: product,
                            baseUrl: serverBaseUrl,
                          ),
                          // Badges de estado: solo visibles cuando los
                          // toggles muestran estos productos (con los
                          // toggles apagados ni siquiera se dibujan).
                          if (!hasStock || !product.isVisible)
                            Positioned(
                              top: 6,
                              left: 6,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!hasStock)
                                    const _StatusBadge(
                                      label: 'AGOTADO',
                                      color: Colors.red,
                                    ),
                                  if (!hasStock && !product.isVisible)
                                    const SizedBox(width: 4),
                                  if (!product.isVisible)
                                    const _StatusBadge(
                                      label: 'OCULTO',
                                      color: Colors.blueGrey,
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Pila del bloque inferior: el chip "Ver" se ancla a la
                    // esquina de la tarjeta (no a la de la imagen), así no
                    // tapa la foto. El tap del chip no abre el diálogo de
                    // variantes: gana el hijo.
                    Stack(
                      children: [
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
                        if (imageUrls.isNotEmpty)
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Material(
                              color: Colors.black.withValues(alpha: 0.45),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color:
                                      Colors.white.withValues(alpha: 0.25),
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => ProductImageViewer.show(
                                  context,
                                  title: product.name,
                                  urls: imageUrls,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.zoom_in,
                                        size: 13,
                                        color: Colors.white
                                            .withValues(alpha: 0.9),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Ver',
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.9),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
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

/// Chip compacto de estado sobre la foto del producto (AGOTADO / OCULTO).
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// Categories bottom sheet
// ─────────────────────────────────────────────────────────────
void openCategoriesModal(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (modalContext) {
      // IMPORTANTE: `ref.watch` dentro de un Consumer. Antes el AsyncValue
      // se capturaba con `ref.read` al abrir la hoja: la primera vez el
      // future aún no resolvía y NADA reconstruía el builder, así que el
      // spinner giraba para siempre; al reabrirla el provider ya tenía
      // datos y la lista aparecía "instantánea". Con watch, la hoja se
      // reconstruye cuando la FutureProvider resuelve (o falla).
      return Consumer(
        builder: (context, ref, _) {
          final selectedCategory = ref.watch(selectedCategoryProvider);
          final categoriesAsync = ref.watch(categoriesProvider);

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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Error al cargar categorías: $err',
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Reintentar'),
                            onPressed: () =>
                                ref.invalidate(categoriesProvider),
                          ),
                        ],
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
    },
  );
}

// ─────────────────────────────────────────────────────────────
// Checkout bottom sheet (shared by both layouts)
// ─────────────────────────────────────────────────────────────
/// Delta de catálogo tras una orden (enviada o rechazada): el stock local
/// quedó viejo en cualquier caso y hay que refrescar la grilla.
void _syncAfterOrder(WidgetRef ref) {
  ref.read(syncServiceProvider).sync().then((result) {
    if (result.ok) {
      ref
        ..invalidate(productsProvider)
        ..invalidate(categoriesProvider);
    }
  });
}

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
      // La hoja modal está anclada al BORDE INFERIOR de la pantalla, así que el
      // inset del teclado hay que aplicarlo AQUÍ (una sola vez) para que la
      // hoja crezca y quede por encima del teclado en vez de tapada por él.
      //
      // Por eso `CheckoutScreen` va con `resizeToAvoidBottomInset: false`: si
      // el `Scaffold` también descontara el teclado, se contaría dos veces y
      // quedaría un área en blanco del tamaño del teclado tapando los campos.
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(dialogContext).viewInsets.bottom,
        ),
        child: CheckoutScreen(
          cartItems: orderItems,
          subtotal: cartNotifier.subtotal,
          currentRate: currentRate,
          onSubmitOrder: (orderPayload) async {
            // La orden SIEMPRE se encola primero (clave idempotente) y se
            // intenta enviar ya mismo. Sin red queda guardada y se manda
            // sola al reconectar; si el server la rechaza por negocio
            // (stock), el cajero la edita o la descarta.
            final outbox = ref.read(outboxServiceProvider);
            final result = await outbox.submit(orderPayload.toJson());
            if (!context.mounted) return;

            final messenger = ScaffoldMessenger.of(context);
            switch (result.outcome) {
              case OutboxOutcome.sent:
                Navigator.of(dialogContext).pop();
                cartNotifier.clear();
                _syncAfterOrder(ref);
                messenger.showSnackBar(SnackBar(
                  content: Text(
                      '¡Orden #${result.orderId} creada exitosamente! Total: Bs. ${result.totalBs ?? ''}'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 4),
                ));
              case OutboxOutcome.waiting:
                Navigator.of(dialogContext).pop();
                cartNotifier.clear();
                messenger.showSnackBar(const SnackBar(
                  content: Text(
                      'Sin conexión: la orden quedó guardada y se enviará '
                      'automaticamente al reconectar.'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 5),
                ));
              case OutboxOutcome.attention:
                // Rechazo de negocio: la venta NO ocurrió y la orden queda
                // en la cola a merced del cajero (editar o descartar).
                Navigator.of(dialogContext).pop();
                cartNotifier.clear();
                if (result.errorCode == 'INSUFFICIENT_STOCK') {
                  await OrderConflictDialog.show(context, result.localId);
                } else {
                  messenger.showSnackBar(SnackBar(
                    content: Text(
                        '${result.errorMessage ?? 'El servidor rechazó la orden.'} '
                        'Ingresa a "Órdenes fuera de línea" para editarla '
                        'o descartarla.'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 6),
                  ));
                }
                _syncAfterOrder(ref);
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

  List<String> _getImageUrls() =>
      productImageUrls(widget.product, widget.baseUrl);

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
              return CatalogImage(
                imageUrl: imageUrls[index],
                fit: BoxFit.cover,
                // Decodifica al ancho de la tarjeta (~200dp): mucha menos
                // memoria y scroll más fluido. En disco se guarda el
                // original a tamaño completo (para el visor con zoom).
                memCacheWidth: 600,
                placeholder: (_, _) => const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (_, _, _) => const Center(
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
