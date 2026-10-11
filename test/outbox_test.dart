import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:naavis_pos/core/db/app_database.dart';
import 'package:naavis_pos/features/checkout/data/outbox_repository.dart';
import 'package:naavis_pos/features/checkout/data/outbox_service.dart';

/// Adaptador HTTP falso: cada test decide qué responde
/// y registra las peticiones para poder evaluar headers y payloads.
class _FakeAdapter implements HttpClientAdapter {
  Future<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  _FakeAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}

  static ResponseBody json(Object body, {int status = 200}) {
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  static DioException offline(RequestOptions options) =>
      DioException.connectionError(
        requestOptions: options,
        reason: 'sin red',
      );
}

/// Error de negocio 409 con el envelope de `errors.py`.
ResponseBody _insufficientStock(RequestOptions options) {
  return _FakeAdapter.json({
    'detail': 'Stock insuficiente para Café (Normal). Disponible: 1',
    'error': {
      'code': 'INSUFFICIENT_STOCK',
      'message': 'Stock insuficiente para Café (Normal). Disponible: 1',
      'details': {
        'variation_id': 7,
        'product': 'Café',
        'variation_type': 'Normal',
        'requested': 3,
        'available': 1,
      },
      'retryable': false,
      'request_id': 'abc',
    },
  }, status: 409);
}

Map<String, dynamic> _payload() => {
      'customer_name': 'Ana',
      'delivery_type': 'PICKUP',
      'payment_method': 'EFECTIVO_USD',
      'payment_ref': null,
      'coupon_code': null,
      'discount_volumen': 0.0,
      'note': null,
      'items': [
        {'variation_id': 7, 'quantity': 3},
      ],
    };

void main() {
  late AppDatabase db;
  late OutboxRepository repo;
  late Dio dio;
  late _FakeAdapter adapter;
  late OutboxService service;
  late List<String> onOrderSentCalls;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = OutboxRepository(db);
    adapter = _FakeAdapter((_) async =>
        _FakeAdapter.json({'id': 42, 'total_bs': 120.0}));
    dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'))
      ..httpClientAdapter = adapter;
    onOrderSentCalls = [];
    service = OutboxService(
      dio,
      repo,
      onOrderSent: () => onOrderSentCalls.add('sent'),
    );
  });

  tearDown(() async {
    // Drena los microtasks del chequeo del timer antes de cancelarlo.
    await Future<void>.delayed(Duration.zero);
    service.dispose();
    await db.close();
  });

  test('submit con éxito: borra la fila, reporta orderId y avisa', () async {
    final result = await service.submit(_payload());

    expect(result.outcome, OutboxOutcome.sent);
    expect(result.orderId, 42);
    expect(result.totalBs, '120.0');
    expect(await repo.listByStatus(outboxStatusPending), isEmpty);
    expect(onOrderSentCalls, hasLength(1));

    // Siempre se envía con Idempotency-Key generada en el cliente.
    final request = adapter.requests.single;
    expect(request.headers['Idempotency-Key'], isNotNull);
    expect(request.headers['Idempotency-Key'].length, lessThanOrEqualTo(64));
  });

  test('sin conexión: queda pending y se puede reintentar con la MISMA clave',
      () async {
    adapter.handler = (options) async => throw _FakeAdapter.offline(options);
    final offlineResult = await service.submit(_payload());
    expect(offlineResult.outcome, OutboxOutcome.waiting);

    final pending = await repo.listByStatus(outboxStatusPending);
    expect(pending, hasLength(1));
    final firstKey = pending.single.idempotencyKey;

    // Vuelve la red: retryNow usa la fila guardada (misma clave).
    adapter.handler = (options) async =>
        _FakeAdapter.json({'id': 43, 'total_bs': 10.0});
    await service.retryNow(pending.single.localId);

    expect(await repo.listByStatus(outboxStatusPending), isEmpty);
    expect(adapter.requests, hasLength(2));
    expect(adapter.requests.last.headers['Idempotency-Key'], firstKey);
    expect(adapter.requests.last.uri.path, contains('/orders'));
  });

  test('409 INSUFFICIENT_STOCK: queda attention con sus detalles', () async {
    adapter.handler = (options) async => _insufficientStock(options);
    final result = await service.submit(_payload());

    expect(result.outcome, OutboxOutcome.attention);
    expect(result.errorCode, 'INSUFFICIENT_STOCK');

    final rows = await repo.listByStatus(outboxStatusAttention);
    expect(rows, hasLength(1));
    expect(rows.single.isStockConflict, isTrue);
    expect(rows.single.errorDetails?['available'], 1);
    expect(rows.single.payload['items'], hasLength(1));
  });

  test('5xx retryable: queda pending (nunca attention)', () async {
    adapter.handler = (options) async => _FakeAdapter.json({
          'detail': 'Error interno',
          'error': {
            'code': 'INTERNAL_ERROR',
            'message': 'Error interno del servidor.',
            'retryable': true,
          },
        }, status: 500);
    final result = await service.submit(_payload());

    expect(result.outcome, OutboxOutcome.waiting);
    expect(await repo.listByStatus(outboxStatusPending), hasLength(1));
    expect(await repo.listByStatus(outboxStatusAttention), isEmpty);
  });

  test('flush barre pending pero NUNCA reenvía attention', () async {
    adapter.handler = (options) async => _insufficientStock(options);
    await service.submit(_payload());
    expect(await repo.listByStatus(outboxStatusAttention), hasLength(1));

    // La red "vuelve": un flush no debe tocar la fila en atención.
    adapter.handler = (options) async =>
        _FakeAdapter.json({'id': 99, 'total_bs': 1.0});
    await service.flush();

    expect(adapter.requests, hasLength(1)); // solo el submit original
    expect(await repo.listByStatus(outboxStatusAttention), hasLength(1));
  });

  test('saveEditAndRetry actualiza el payload y reintenta con la misma clave',
      () async {
    adapter.handler = (options) async => _insufficientStock(options);
    await service.submit(_payload());
    final row = (await repo.listByStatus(outboxStatusAttention)).single;
    final key = row.idempotencyKey;

    // El cajero acota la cantidad al stock disponible y reintenta.
    final edited = Map<String, dynamic>.from(row.payload);
    edited['items'] = [
      {'variation_id': 7, 'quantity': 1},
    ];
    adapter.handler = (options) async =>
        _FakeAdapter.json({'id': 50, 'total_bs': 5.0});
    final result = await service.saveEditAndRetry(row.localId, edited);

    expect(result.outcome, OutboxOutcome.sent);
    expect(result.orderId, 50);
    expect(await repo.listByStatus(outboxStatusAttention), isEmpty);

    final resent = adapter.requests.last;
    expect(resent.headers['Idempotency-Key'], key);
    // dio puede entregar el body ya serializado (String) o como Map.
    final rawData = resent.data;
    final body = jsonDecode(rawData is String
        ? rawData
        : jsonEncode(rawData)) as Map<String, dynamic>;
    expect((body['items'] as List).single['quantity'], 1);
  });

  test('discard elimina la orden local sin tocar el server', () async {
    adapter.handler = (options) async => _insufficientStock(options);
    await service.submit(_payload());
    final row = (await repo.listByStatus(outboxStatusAttention)).single;

    await service.discard(row.localId);

    expect(await repo.listByStatus(outboxStatusAttention), isEmpty);
    expect(await repo.listByStatus(outboxStatusPending), isEmpty);
  });
}
