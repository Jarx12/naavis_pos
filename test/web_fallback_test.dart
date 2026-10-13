import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:naavis_pos/core/db/prefs_settings_store.dart';
import 'package:naavis_pos/features/catalog/domain/category_model.dart';
import 'package:naavis_pos/features/catalog/data/in_memory_catalog_repository.dart';
import 'package:naavis_pos/features/checkout/data/outbox_repository.dart';
import 'package:naavis_pos/features/checkout/data/prefs_cart_store.dart';
import 'package:naavis_pos/features/checkout/data/prefs_outbox_repository.dart';
import 'package:naavis_pos/features/checkout/domain/cart_item_model.dart';
import 'package:naavis_pos/features/sync/data/sync_models.dart';
import 'package:naavis_pos/features/sync/data/sync_repository.dart';
import 'package:naavis_pos/features/sync/data/sync_service.dart';

/// Remote falso mínimo: siempre devuelve la página pedida.
class _FakeRemote implements SyncRepository {
  final List<SyncPage> pages;
  final List<String?> requestedSinces = [];

  _FakeRemote(this.pages);

  @override
  Future<SyncPage> fetchPage({String? since, int offset = 0}) async {
    requestedSinces.add(since);
    return pages.first;
  }
}

SyncPage _page({
  required String serverTime,
  List<Map<String, dynamic>> products = const [],
  List<Map<String, dynamic>> categories = const [],
  List<int> deletedProducts = const [],
  List<int> deletedVariations = const [],
  List<int> deletedCategories = const [],
}) {
  return SyncPage(
    serverTime: serverTime,
    products: products,
    categories: categories,
    deletedProducts: deletedProducts,
    deletedVariations: deletedVariations,
    deletedCategories: deletedCategories,
    hasMore: false,
  );
}

Map<String, dynamic> _product({
  int id = 1,
  String name = 'Café',
  int stock = 5,
  String imageUrl = '/media/x.jpg',
  List<Map<String, dynamic>>? variations,
}) {
  return {
    'id': id,
    'name': name,
    'price': 10.0,
    'final_price': 8.0,
    'discount_percentage': 20,
    'description': 'desc',
    'total_stock': stock,
    'cost': 4.0,
    'is_visible': true,
    'categories': [
      {'id': 1, 'name': 'Bebidas'}
    ],
    'variations': variations ??
        [
          {
            'id': id * 100,
            'variation_type': 'Normal',
            'stock': stock,
            'search_tags': '',
          },
          {
            'id': id * 100 + 1,
            'variation_type': 'Grande',
            'stock': stock + 2,
            'search_tags': null,
          },
        ],
    'images': [
      {
        'id': id * 1000,
        'image_url': imageUrl,
        'thumbnail_url': null,
        'is_main': true,
      }
    ],
  };
}

void main() {
  group('InMemoryCatalogRepository', () {
    late InMemoryCatalogRepository repo;

    setUp(() => repo = InMemoryCatalogRepository());

    test('seed aplica productos con hijos y resuelve categorías', () async {
      final changed = await repo.applyPage(_page(
        serverTime: 'T1',
        products: [_product()],
        categories: [
          {'id': 1, 'name': 'Bebidas'}
        ],
      ));
      expect(changed, isTrue);

      final products = await repo.getProducts();
      expect(products, hasLength(1));
      expect(products.single.name, 'Café');
      expect(products.single.variations, hasLength(2));
      expect(products.single.categories.single.name, 'Bebidas');
      expect(await repo.getCategories(),
          [const CategoryOut(id: 1, name: 'Bebidas')]);
    });

    test('renombrar categoría top-level pisa el nombre viejo', () async {
      await repo.applyPage(_page(
        serverTime: 'T1',
        products: [_product()],
        categories: [
          {'id': 1, 'name': 'Bebidas'}
        ],
      ));
      await repo.applyPage(_page(serverTime: 'T2', categories: [
        {'id': 1, 'name': 'Nueva'}
      ]));
      expect((await repo.getProducts()).single.categories.single.name, 'Nueva');
    });

    test('delta reemplaza hijos completos y aplica tumbas', () async {
      await repo.applyPage(_page(
        serverTime: 'T1',
        products: [_product()],
        categories: [
          {'id': 1, 'name': 'Bebidas'}
        ],
      ));

      // Reemplazo completo: una sola variación, se pierde la segunda.
      await repo.applyPage(_page(serverTime: 'T2', products: [
        _product(variations: [
          {
            'id': 100,
            'variation_type': 'Normal',
            'stock': 1,
            'search_tags': '',
          }
        ]),
      ]));
      expect((await repo.getProducts()).single.variations, hasLength(1));

      await repo.applyPage(_page(serverTime: 'T3', deletedVariations: [100]));
      expect((await repo.getProducts()).single.variations, isEmpty);

      await repo.applyPage(_page(serverTime: 'T4', deletedCategories: [1]));
      expect((await repo.getProducts()).single.categories, isEmpty);

      await repo.applyPage(_page(serverTime: 'T5', deletedProducts: [1]));
      expect(await repo.getProducts(), isEmpty);
    });

    test('siempre arranca sin cursor (seed completo por sesión)', () async {
      final cursor = await repo.readSyncState();
      expect(cursor.seeded, isFalse);
      expect(cursor.serverTime, isNull);
      await repo.saveCursor('T9');
      expect((await repo.readSyncState()).serverTime, isNull);
    });

    test('getImageUrls y getVariationInfo', () async {
      await repo.applyPage(_page(
          serverTime: 'T1', products: [_product(imageUrl: '/media/a.jpg')]));
      expect(await repo.getImageUrls(), ['/media/a.jpg']);

      final info = await repo.getVariationInfo(100);
      expect(info, isNotNull);
      expect(info!.label, 'Café (Normal)');
      expect(info.stock, 5);
      expect(await repo.getVariationInfo(999), isNull);
    });
  });

  group('SyncService sobre catálogo en memoria', () {
    test('seed llena la memoria; una sesión nueva arranca vacía', () async {
      final remote = _FakeRemote([
        _page(serverTime: 'T1', products: [_product()]),
      ]);
      final repo = InMemoryCatalogRepository();

      final result = await SyncService(remote, repo).sync();
      expect(result.ok, isTrue);
      expect(result.changed, isTrue);
      expect(await repo.getProducts(), hasLength(1));

      // Sin persistencia: la próxima sesión vuelve a pedir el seed entero.
      expect(await InMemoryCatalogRepository().getProducts(), isEmpty);
    });

    test('sin cursor el remote siempre recibe since=null', () async {
      final remote = _FakeRemote([_page(serverTime: 'T1')]);
      final result =
          await SyncService(remote, InMemoryCatalogRepository()).sync();
      expect(result.ok, isTrue);
      expect(remote.requestedSinces, [null]);
    });
  });

  group('PrefsCartStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('roundtrip de guardado completo (sobrevive instancias)', () async {
      final store = PrefsCartStore();
      expect(await store.load(), isEmpty);

      await store.saveAll([
        CartItem(
            variationId: 1,
            productName: 'Café',
            price: 2.5,
            quantity: 3,
            maxStock: 10),
        CartItem(
            variationId: 2,
            productName: 'Té',
            price: 1.0,
            quantity: 1,
            maxStock: 4),
      ]);

      final loaded = await store.load();
      expect(loaded, hasLength(2));
      expect(loaded.first.variationId, 1);
      expect(loaded.first.productName, 'Café');
      expect(loaded.first.price, 2.5);
      expect((await PrefsCartStore().load()).last.variationId, 2);
    });
  });

  group('PrefsOutboxRepository', () {
    late PrefsOutboxRepository repo;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repo = PrefsOutboxRepository();
    });

    test('enqueue asigna ids crecientes y lista por estado', () async {
      final a =
          await repo.enqueue(idempotencyKey: 'k1', payload: {'items': []});
      final b =
          await repo.enqueue(idempotencyKey: 'k2', payload: {'items': []});
      expect([a, b], [1, 2]);
      expect(await repo.listByStatus(outboxStatusPending), hasLength(2));
      expect((await repo.getById(a))!.idempotencyKey, 'k1');
    });

    test('markAttention guarda el error y resetForRetry lo limpia', () async {
      final id = await repo.enqueue(idempotencyKey: 'k', payload: {'n': 1});
      await repo.markAttention(
        id,
        code: 'INSUFFICIENT_STOCK',
        message: 'Stock insuficiente',
        detailsJson: '{"available": 2}',
      );

      var row = (await repo.getById(id))!;
      expect(row.needsAttention, isTrue);
      expect(row.errorCode, 'INSUFFICIENT_STOCK');
      expect(row.errorDetails!['available'], 2);

      await repo.resetForRetry(id, payloadJson: '{"n": 9}');
      row = (await repo.getById(id))!;
      expect(row.status, outboxStatusPending);
      expect(row.errorCode, isNull);
      expect(row.payload, {'n': 9});
    });

    test('bumpAttempt, delete y persistencia entre instancias', () async {
      final id = await repo.enqueue(idempotencyKey: 'k', payload: {});
      await repo.bumpAttempt(id);
      expect((await repo.getById(id))!.attempts, 1);

      // "Recarga de la PWA": instancia nueva leyendo de prefs.
      final reloaded = PrefsOutboxRepository();
      expect((await reloaded.getById(id))!.attempts, 1);

      await reloaded.delete(id);
      expect(await reloaded.getById(id), isNull);
      expect(await reloaded.listByStatus(outboxStatusPending), isEmpty);
    });

    test('watchAll emite el estado actual y cada mutación', () async {
      final events = <List<OutboxRow>>[];
      final sub = repo.watchAll().listen(events.add);
      await Future<void>.delayed(Duration.zero);

      await repo.enqueue(idempotencyKey: 'k', payload: {});
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(2));
      expect(events.first, isEmpty);
      expect(events.last, hasLength(1));
      await sub.cancel();
    });
  });

  group('PrefsSettingsStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('roundtrip con namespace propio', () async {
      final store = PrefsSettingsStore();
      expect(await store.get('rate'), isNull);
      await store.set('rate', '{"x":1}');
      expect(await store.get('rate'), '{"x":1}');
      expect(await PrefsSettingsStore().get('rate'), '{"x":1}');
    });
  });
}
