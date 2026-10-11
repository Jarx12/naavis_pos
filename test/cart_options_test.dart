import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:naavis_pos/core/db/app_database.dart';
import 'package:naavis_pos/core/db/app_providers.dart';
import 'package:naavis_pos/features/checkout/data/cart_store.dart';
import 'package:naavis_pos/features/checkout/domain/cart_item_model.dart';
import 'package:naavis_pos/features/checkout/presentation/providers/cart_provider.dart';
import 'package:naavis_pos/features/checkout/presentation/providers/display_options.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('CartStore', () {
    test('guardar y recargar el carrito (roundtrip)', () async {
      final store = CartStore(db);
      await store.saveAll([
        CartItem(
          variationId: 7,
          productName: 'Café - Normal',
          price: 8.5,
          quantity: 2,
          maxStock: 5,
        ),
      ]);

      final loaded = await store.load();
      expect(loaded, hasLength(1));
      expect(loaded.single.variationId, 7);
      expect(loaded.single.productName, 'Café - Normal');
      expect(loaded.single.quantity, 2);
      expect(loaded.single.maxStock, 5);
    });

    test('saveAll vacío limpia la tabla', () async {
      final store = CartStore(db);
      await store.saveAll([
        CartItem(
            variationId: 1,
            productName: 'x',
            price: 1,
            quantity: 1,
            maxStock: 1),
      ]);
      await store.saveAll(const []);
      expect(await store.load(), isEmpty);
    });
  });

  group('CartNotifier', () {
    test('hidrata desde la base local al construirse', () async {
      await CartStore(db).saveAll([
        CartItem(
            variationId: 3,
            productName: 'Guardado',
            price: 2,
            quantity: 4,
            maxStock: 9),
      ]);

      final container = makeContainer();
      expect(container.read(cartProvider), isEmpty);
      await Future<void>.delayed(Duration.zero);

      final items = container.read(cartProvider);
      expect(items, hasLength(1));
      expect(items.single.productName, 'Guardado');
      expect(items.single.quantity, 4);
    });

    test('addProduct con stock 0 nunca entra al carrito', () async {
      final container = makeContainer();
      await Future<void>.delayed(Duration.zero);

      final notifier = container.read(cartProvider.notifier);
      notifier.addProduct(
          variationId: 1, name: 'Agotado', price: 5, maxStock: 0);
      expect(container.read(cartProvider), isEmpty);

      notifier.addProduct(
          variationId: 2, name: 'OK', price: 5, maxStock: 3);
      expect(container.read(cartProvider), hasLength(1));
    });

    test('cada mutación persiste el carrito en la base', () async {
      final container = makeContainer();
      await Future<void>.delayed(Duration.zero);

      container.read(cartProvider.notifier).addProduct(
          variationId: 9, name: 'Persistido', price: 1, maxStock: 2);
      await Future<void>.delayed(Duration.zero);

      final loaded = await CartStore(db).load();
      expect(loaded, hasLength(1));
      expect(loaded.single.variationId, 9);
    });
  });

  group('DisplayOptions', () {
    test('arranca con ambos toggles apagados', () async {
      final container = makeContainer();
      await Future<void>.delayed(Duration.zero);
      final options = container.read(displayOptionsProvider);
      expect(options.showInvisible, isFalse);
      expect(options.showOutOfStock, isFalse);
    });

    test('los toggles se persisten en SharedPreferences', () async {
      final container = makeContainer();
      await Future<void>.delayed(Duration.zero);

      container
          .read(displayOptionsProvider.notifier)
          .setShowOutOfStock(true);
      await Future<void>.delayed(Duration.zero);

      // Nuevo contenedor (app reiniciada): debe restaurar el toggle.
      final second = ProviderContainer();
      addTearDown(second.dispose);
      expect(second.read(displayOptionsProvider).showOutOfStock, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(second.read(displayOptionsProvider).showOutOfStock, isTrue);
    });
  });
}