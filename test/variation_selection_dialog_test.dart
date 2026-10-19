import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:naavis_pos/core/images/catalog_image.dart';
import 'package:naavis_pos/features/catalog/domain/product_model.dart';
import 'package:naavis_pos/features/checkout/presentation/widgets/variation_selection_dialog.dart';

/// Escritorio con dos variantes: "Acero" con foto propia y stock, "Madera"
/// agotada sin foto (su cuadro queda de placeholder).
ProductDetailOut buildProduct({bool variantHasImage = true}) =>
    ProductDetailOut(
      id: 1,
      name: 'Escritorio',
      price: 862.5,
      finalPrice: 862.5,
      discountPercentage: 0,
      description: 'x',
      totalStock: 2,
      cost: 100,
      isVisible: true,
      variations: const [
        VariationOut(id: 11, variationType: 'Acero', stock: 2),
        VariationOut(id: 12, variationType: 'Madera', stock: 0),
      ],
      images: [
        if (variantHasImage)
          const ProductImageOut(
            id: 5,
            imageUrl: '/media/acero.webp',
            thumbnailUrl: '/media/acero_thumb.webp',
            isMain: true,
            variationIds: [11],
          ),
        const ProductImageOut(id: 6, imageUrl: '/media/general.webp'),
      ],
    );

void main() {
  setUp(() {
    // Sin disco en tests: la rama de red nunca cuelga el FakeAsync.
    CatalogImage.useDiskCache = false;
  });

  Future<void> openDialog(
    WidgetTester tester, {
    required void Function(VariationOut) onSelected,
    ProductDetailOut? product,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => VariationSelectionDialog(
                    product: product ?? buildProduct(),
                    onVariationSelected: onSelected,
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  group('ProductImageOut variationIds', () {
    test('variation_ids se parsea y por defecto queda vacío', () {
      final conFoto = ProductImageOut.fromJson(
          {'id': 1, 'image_url': '/media/a.webp', 'variation_ids': [11]});
      expect(conFoto.variationIds, [11]);

      final general =
          ProductImageOut.fromJson({'id': 2, 'image_url': '/media/b.webp'});
      expect(general.variationIds, isEmpty);
    });
  });

  testWidgets('mantiene nombre, subtítulo con precio y sin botón Agregar',
      (tester) async {
    await openDialog(tester, onSelected: (_) {});

    expect(find.text('Escritorio'), findsOneWidget);
    expect(
      find.text('Selecciona una variante (Precio: \$862.5)'),
      findsOneWidget,
    );
    expect(find.text('Acero'), findsOneWidget);
    expect(find.text('Madera'), findsOneWidget);
    // El botón por fila se retiró.
    expect(find.text('Agregar'), findsNothing);
    // Indicadores de agotado: badge sobre el cuadro + texto de stock.
    expect(find.text('AGOTADO'), findsOneWidget);
    expect(find.text('Agotado'), findsOneWidget);
    expect(find.text('Stock disponible: 2'), findsOneWidget);
  });

  testWidgets('tocar la fila agrega la variante y cierra el diálogo',
      (tester) async {
    VariationOut? selected;
    await openDialog(tester, onSelected: (v) => selected = v);

    await tester.tap(find.text('Acero'));
    await tester.pumpAndSettle();

    expect(selected?.id, 11);
    expect(find.text('Escritorio'), findsNothing); // cerrado
  });

  testWidgets('la fila agotada no agrega ni cierra', (tester) async {
    VariationOut? selected;
    await openDialog(tester, onSelected: (v) => selected = v);

    await tester.tap(find.text('Madera'));
    await tester.pumpAndSettle();

    expect(selected, isNull);
    expect(find.text('Escritorio'), findsOneWidget); // sigue abierto
  });

  testWidgets('el cuadro con foto abre el visor sin agregar', (tester) async {
    VariationOut? selected;
    await openDialog(tester, onSelected: (v) => selected = v);

    await tester.tap(find.byTooltip('Ver foto').first);
    await tester.pumpAndSettle();

    expect(selected, isNull); // el cuadro NO agrega
    expect(find.byTooltip('Cerrar'), findsOneWidget); // visor abierto
  });

  testWidgets('el placeholder abre la galería del producto', (tester) async {
    VariationOut? selected;
    await openDialog(
      tester,
      onSelected: (v) => selected = v,
      product: buildProduct(variantHasImage: false),
    );

    // Ninguna variante tiene foto: los cuadros son placeholder.
    await tester.tap(find.byIcon(Icons.image_outlined).first);
    await tester.pumpAndSettle();

    expect(selected, isNull);
    expect(find.byTooltip('Cerrar'), findsOneWidget); // galería en el visor
  });
}