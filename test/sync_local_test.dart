import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:naavis_pos/core/db/app_database.dart';
import 'package:naavis_pos/features/catalog/data/local_catalog_repository.dart';
import 'package:naavis_pos/features/sync/data/sync_models.dart';
import 'package:naavis_pos/features/sync/data/sync_repository.dart';
import 'package:naavis_pos/features/sync/data/sync_service.dart';

/// Remote falso: registra cada llamada y devuelve las páginas pedidas.
class _FakeRemote implements SyncRepository {
  final List<SyncPage> pagesByOffset;
  final List<int> requestedOffsets = [];
  final List<String?> requestedSinces = [];
  DioException? failure;

  _FakeRemote(this.pagesByOffset);

  @override
  Future<SyncPage> fetchPage({String? since, int offset = 0}) async {
    requestedOffsets.add(offset);
    requestedSinces.add(since);
    final failure = this.failure;
    if (failure != null) throw failure;
    return pagesByOffset[offset == 0 ? 0 : pagesByOffset.length - 1];
  }
}

SyncPage _page({
  required String serverTime,
  List<Map<String, dynamic>> products = const [],
  List<Map<String, dynamic>> categories = const [],
  List<int> deletedProducts = const [],
  List<int> deletedVariations = const [],
  List<int> deletedCategories = const [],
  bool hasMore = false,
}) {
  return SyncPage(
    serverTime: serverTime,
    products: products,
    categories: categories,
    deletedProducts: deletedProducts,
    deletedVariations: deletedVariations,
    deletedCategories: deletedCategories,
    hasMore: hasMore,
  );
}

Map<String, dynamic> _product({
  int id = 1,
  String name = 'Café',
  bool isVisible = true,
  int stock = 5,
  List<Map<String, dynamic>> categories = const [
    {'id': 1, 'name': 'Bebidas'}
  ],
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
    'is_visible': isVisible,
    'categories': categories,
    'variations': [
      {
        'id': id * 100,
        'variation_type': 'Normal',
        'stock': stock,
        'search_tags': '',
      }
    ],
    'images': [
      {
        'id': id * 1000,
        'image_url': '/media/x.jpg',
        'thumbnail_url': null,
        'is_main': true,
      }
    ],
  };
}

void main() {
  late AppDatabase db;
  late LocalCatalogRepository local;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    local = LocalCatalogRepository(db);
  });

  tearDown(() => db.close());

  group('LocalCatalogRepository.applyPage', () {
    test('seed: upsert de producto con hijos e ids de categoría', () async {
      final changed = await local.applyPage(_page(
        serverTime: 'T1',
        products: [_product()],
        categories: [
          {'id': 1, 'name': 'Bebidas'}
        ],
      ));
      expect(changed, isTrue);

      final products = await local.getProducts();
      expect(products, hasLength(1));
      final p = products.single;
      expect(p.name, 'Café');
      expect(p.finalPrice, 8.0);
      expect(p.variations.single.stock, 5);
      expect(p.images.single.imageUrl, '/media/x.jpg');
      // El nombre se resuelve por join local, no de la copia embebida.
      expect(p.categories.single.name, 'Bebidas');

      final cursor = await local.readSyncState();
      expect(cursor.seeded, isFalse); // saveCursor lo hace el SyncService
    });

    test('delta: reemplaza los hijos por completo', () async {
      await local.applyPage(_page(
        serverTime: 'T1',
        products: [_product()],
        categories: [
          {'id': 1, 'name': 'Bebidas'}
        ],
      ));
      // Segundo payload del mismo producto: SIN imágenes y otra variación
      // (el delta trae los hijos completos: se reemplazan, no se mezclan).
      final secondPayload = _product(stock: 0)..remove('images');
      final changed = await local.applyPage(_page(
        serverTime: 'T2',
        products: [secondPayload],
      ));

      expect(changed, isTrue);
      final p = (await local.getProducts()).single;
      expect(p.images, isEmpty);
      expect(p.variations.single.stock, 0);
    });

    test('renombrar categoría top-level pisa el nombre viejo', () async {
      await local.applyPage(_page(
        serverTime: 'T1',
        products: [_product()],
        categories: [
          {'id': 1, 'name': 'Vieja'}
        ],
      ));
      await local.applyPage(_page(
        serverTime: 'T2',
        categories: [
          {'id': 1, 'name': 'Nueva'}
        ],
      ));
      expect((await local.getCategories()).single.name, 'Nueva');

      // Un payload de producto con la copia embebida VIEJA no debe pisar
      // el nombre frescho.
      await local.applyPage(_page(
        serverTime: 'T3',
        products: [_product(categories: [
          {'id': 1, 'name': 'Vieja'}
        ])],
      ));
      expect((await local.getCategories()).single.name, 'Nueva');
      expect((await local.getProducts()).single.categories.single.name,
          'Nueva');
    });

    test('tumbas: borra productos, variantes, categorías y sus joins',
        () async {
      await local.applyPage(_page(
        serverTime: 'T1',
        products: [_product()],
        categories: [
          {'id': 1, 'name': 'Bebidas'}
        ],
      ));

      await local.applyPage(_page(
        serverTime: 'T2',
        deletedVariations: [100],
      ));
      expect((await local.getProducts()).single.variations, isEmpty);

      await local.applyPage(_page(
        serverTime: 'T3',
        deletedCategories: [1],
      ));
      expect(await local.getCategories(), isEmpty);
      expect((await local.getProducts()).single.categories, isEmpty);

      await local.applyPage(_page(
        serverTime: 'T4',
        deletedProducts: [1],
      ));
      expect(await local.getProducts(), isEmpty);
    });
  });

  group('SyncService', () {
    test('seed sin cursor y persiste el server_time', () async {
      final remote = _FakeRemote([
        _page(serverTime: 'T1', products: [_product()]),
      ]);
      final service = SyncService(remote, local);

      final result = await service.sync();
      expect(result.ok, isTrue);
      expect(result.changed, isTrue);
      expect(remote.requestedSinces.single, isNull);

      final cursor = await local.readSyncState();
      expect(cursor.seeded, isTrue);
      expect(cursor.serverTime, 'T1');
    });

    test('delta envía el cursor guardado', () async {
      final remote = _FakeRemote([
        _page(serverTime: 'T1', products: [_product()]),
      ]);
      await SyncService(remote, local).sync();

      final delta = _FakeRemote([_page(serverTime: 'T2')]);
      final result = await SyncService(delta, local).sync();
      expect(result.ok, isTrue);
      expect(result.changed, isFalse); // página sin cambios de contenido
      expect(delta.requestedSinces.single, 'T1');
      expect((await local.readSyncState()).serverTime, 'T2');
    });

    test('drain de páginas: offset creciente y cursor = 1ª página',
        () async {
      final remote = _FakeRemote([
        _page(serverTime: 'T1', products: [_product()], hasMore: true),
        _page(serverTime: 'T2', products: [_product(id: 2)], hasMore: false),
      ]);
      // _FakeRemote resuelve por offset: 0 → página 0, >0 → última.
      final result = await SyncService(remote, local).sync();

      expect(result.ok, isTrue);
      expect(remote.requestedOffsets, [0, SyncRepository.pageSize]);
      // El cursor es el de la PRIMERA página (la server_time se toma
      // antes de consultar).
      expect((await local.readSyncState()).serverTime, 'T1');
      expect(await local.getProducts(), hasLength(2));
    });

    test('sin conexión devuelve offline y no toca el cursor', () async {
      final remote = _FakeRemote([_page(serverTime: 'T1')]);
      await SyncService(remote, local).sync();

      final offline = _FakeRemote([_page(serverTime: 'T2')])
        ..failure = DioException.connectionError(
          requestOptions: RequestOptions(path: '/sync/catalog'),
          reason: 'sin red',
        );
      final result = await SyncService(offline, local).sync();

      expect(result.ok, isFalse);
      expect(result.offline, isTrue);
      expect((await local.readSyncState()).serverTime, 'T1');
    });
  });
}
