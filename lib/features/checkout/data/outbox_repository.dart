import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/app_providers.dart';

/// La fila se reenviará sola (red volvió, 5xx, 429…).
const outboxStatusPending = 'pending';

/// El server rechazó la orden por regla de negocio (p.ej.
/// `INSUFFICIENT_STOCK`): NUNCA se reenvía sola; el cajero la edita o la
/// descarta desde la hoja de órdenes pendientes.
const outboxStatusAttention = 'attention';

/// Fila de la cola de órdenes mapeada a un objeto cómodo.
class OutboxRow {
  final int localId;
  final String idempotencyKey;
  final Map<String, dynamic> payload;
  final String status;
  final String? errorCode;
  final String? errorMessage;
  final Map<String, dynamic>? errorDetails;
  final int attempts;
  final DateTime createdAt;

  const OutboxRow({
    required this.localId,
    required this.idempotencyKey,
    required this.payload,
    required this.status,
    this.errorCode,
    this.errorMessage,
    this.errorDetails,
    required this.attempts,
    required this.createdAt,
  });

  bool get needsAttention => status == outboxStatusAttention;

  /// true si el rechazo fue por stock insuficiente (abre el diálogo de
  /// edición de cantidades).
  bool get isStockConflict => errorCode == 'INSUFFICIENT_STOCK';

  factory OutboxRow.fromData(OutboxOrder data) {
    Map<String, dynamic>? decodeDetails() {
      final raw = data.errorDetails;
      if (raw == null || raw.isEmpty) return null;
      try {
        final decoded = jsonDecode(raw);
        return decoded is Map<String, dynamic> ? decoded : null;
      } catch (_) {
        return null;
      }
    }

    Map<String, dynamic> decodePayload() {
      try {
        final decoded = jsonDecode(data.payload);
        return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      } catch (_) {
        return <String, dynamic>{};
      }
    }

    return OutboxRow(
      localId: data.localId,
      idempotencyKey: data.idempotencyKey,
      payload: decodePayload(),
      status: data.status,
      errorCode: data.errorCode,
      errorMessage: data.errorMessage,
      errorDetails: decodeDetails(),
      attempts: data.attempts,
      createdAt: data.createdAt,
    );
  }
}

/// Acceso a la tabla `outbox_orders`.
class OutboxRepository {
  final AppDatabase _db;

  OutboxRepository(this._db);

  /// Clave idempotente generada EN EL CLIENTE al encolar (uuid v4). El
  /// server la guarda en `Order.client_ref` y los reintentos con la misma
  /// clave devuelven el mismo pedido sin duplicar.
  static String newIdempotencyKey() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // versión 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variante RFC 4122
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<int> enqueue({
    required String idempotencyKey,
    required Map<String, dynamic> payload,
  }) {
    // Companion: `localId` es autoIncrement y lo asigna la base.
    return _db.into(_db.outboxOrders).insert(OutboxOrdersCompanion(
          idempotencyKey: Value(idempotencyKey),
          payload: Value(jsonEncode(payload)),
          status: const Value(outboxStatusPending),
          attempts: const Value(0),
          createdAt: Value(DateTime.now()),
        ));
  }

  Future<OutboxRow?> getById(int localId) async {
    final data = await (_db.select(_db.outboxOrders)
          ..where((t) => t.localId.equals(localId)))
        .getSingleOrNull();
    return data == null ? null : OutboxRow.fromData(data);
  }

  Future<List<OutboxRow>> listByStatus(String status) async {
    final rows = await (_db.select(_db.outboxOrders)
          ..where((t) => t.status.equals(status))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    return rows.map(OutboxRow.fromData).toList();
  }

  Future<void> markAttention(
    int localId, {
    required String? code,
    required String message,
    String? detailsJson,
  }) {
    return (_db.update(_db.outboxOrders)
          ..where((t) => t.localId.equals(localId)))
        .write(OutboxOrdersCompanion(
      status: const Value(outboxStatusAttention),
      errorCode: Value(code),
      errorMessage: Value(message),
      errorDetails: Value(detailsJson),
    ));
  }

  Future<void> bumpAttempt(int localId) async {
    final row = await (_db.select(_db.outboxOrders)
          ..where((t) => t.localId.equals(localId)))
        .getSingleOrNull();
    if (row == null) return;
    await (_db.update(_db.outboxOrders)
          ..where((t) => t.localId.equals(localId)))
        .write(OutboxOrdersCompanion(attempts: Value(row.attempts + 1)));
  }

  /// Edición del cajero: payload nuevo y vuelta a `pending` (se limpia el
  /// error). La clave idempotente NO cambia: si el primer intento no llegó
  /// a crear la orden (409), reusarla es seguro.
  Future<void> resetForRetry(int localId, {String? payloadJson}) {
    return (_db.update(_db.outboxOrders)
          ..where((t) => t.localId.equals(localId)))
        .write(OutboxOrdersCompanion(
      payload: payloadJson != null
          ? Value(payloadJson)
          : const Value.absent(),
      status: const Value(outboxStatusPending),
      errorCode: const Value(null),
      errorMessage: const Value(null),
      errorDetails: const Value(null),
    ));
  }

  Future<void> delete(int localId) {
    return (_db.delete(_db.outboxOrders)
          ..where((t) => t.localId.equals(localId)))
        .go();
  }

  Stream<List<OutboxRow>> watchAll() {
    return (_db.select(_db.outboxOrders)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch()
        .map((rows) => rows.map(OutboxRow.fromData).toList());
  }
}

final outboxRepositoryProvider = Provider<OutboxRepository>(
  (ref) => OutboxRepository(ref.watch(appDatabaseProvider)),
);
