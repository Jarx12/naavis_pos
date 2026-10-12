import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:naavis_pos/core/db/app_database.dart';
import 'package:naavis_pos/core/images/catalog_image_prefetcher.dart';
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

/// Precachéador de mentira: no toca disco ni red; registra los lotes que
/// la sync le manda y avisa la primera vez que es llamado.
class _RecordingPrefetcher extends CatalogImagePrefetcher {
  final List<List<String>> batches = [];
  final Completer<void> called = Completer<void>();

  @override
  Future<void> prefetch(Iterable<String> urls) async {
    batches.add(urls.toList());
    if (!called.isCompleted) called.complete();
  }
}

Map<String, dynamic> _product({
  int id = 1,
  String name = 'Café',
  bool isVisible = true,
  int stock = 5,
  String imageUrl = '/media/x.jpg',
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
        'image_url': imageUrl,
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

  group('SyncService prefetch de imágenes', () {
    test('seed exitoso precachéa las fotos del catálogo en segundo plano',
        () async {
      final remote = _FakeRemote([
        _page(serverTime: 'T1', products: [_product()]),
      ]);
      final prefetcher = _RecordingPrefetcher();

      final result = await SyncService(
        remote,
        local,
        imagePrefetcher: prefetcher,
      ).sync();

      expect(result.ok, isTrue);
      // El prefetch corre en segundo plano: esperarlo sin bloquear la sync.
      // Llegan las URLs CRUDAS de la DB; la normalización a absolutas y la
      // descarga las hace el prefetcher real (cubiertas en el grupo
      // 'CatalogImagePrefetcher' de abajo).
      await prefetcher.called.future.timeout(const Duration(seconds: 5));
      expect(prefetcher.batches.single, ['/media/x.jpg']);
    });

    test('delta sin cambios también retoma el precache (mejor esfuerzo)',
        () async {
      await SyncService(_FakeRemote([
        _page(serverTime: 'T1', products: [_product()]),
      ]), local).sync(); // sync anterior, sin prefetcher

      final prefetcher = _RecordingPrefetcher();
      final delta = _FakeRemote([_page(serverTime: 'T2')]);
      final result = await SyncService(
        delta,
        local,
        imagePrefetcher: prefetcher,
      ).sync();

      expect(result.ok, isTrue);
      expect(result.changed, isFalse);
      await prefetcher.called.future.timeout(const Duration(seconds: 5));
      expect(prefetcher.batches.single, ['/media/x.jpg']);
    });

    test('sync offline no dispara el prefetch', () async {
      final prefetcher = _RecordingPrefetcher();
      final offline = _FakeRemote([_page(serverTime: 'T1')])
        ..failure = DioException.connectionError(
          requestOptions: RequestOptions(path: '/sync/catalog'),
          reason: 'sin red',
        );

      final result = await SyncService(
        offline,
        local,
        imagePrefetcher: prefetcher,
      ).sync();

      expect(result.offline, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(prefetcher.batches, isEmpty);
    });
  });

  group('CatalogImagePrefetcher', () {
    const base = 'https://pos.example.com/api/v1';

    test('absoluteImageUrl resuelve relativas contra el origin del baseUrl',
        () {
      expect(
        CatalogImagePrefetcher.absoluteImageUrl('/media/a.jpg', baseUrl: base),
        'https://pos.example.com/media/a.jpg',
      );
      expect(
        CatalogImagePrefetcher.absoluteImageUrl(
          '/media/a.jpg',
          baseUrl: 'http://127.0.0.1:8000/api/v1',
        ),
        'http://127.0.0.1:8000/media/a.jpg',
      );
    });

    test('absoluteImageUrl deja pasar las absolutas y las vacías', () {
      expect(
        CatalogImagePrefetcher.absoluteImageUrl(
          'https://cdn.example.com/a.jpg',
          baseUrl: base,
        ),
        'https://cdn.example.com/a.jpg',
      );
      expect(CatalogImagePrefetcher.absoluteImageUrl('', baseUrl: base), '');
    });

    test('normalize deduplica, normaliza y descarta vacías', () {
      final prefetcher = CatalogImagePrefetcher();
      expect(
        prefetcher.normalize([
          '/media/a.jpg',
          '/media/a.jpg',
          '',
          'https://cdn.example.com/b.jpg',
        ]),
        [
          CatalogImagePrefetcher.absoluteImageUrl('/media/a.jpg'),
          'https://cdn.example.com/b.jpg',
        ],
      );
    });
  });
}
