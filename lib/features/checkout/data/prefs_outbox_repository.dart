import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'outbox_repository.dart';

const String _kRowsKey = 'pos_outbox_rows_v1';

/// Cola de órdenes persistida en `localStorage` para los navegadores donde
/// no corre el wasm de drift (ver `core/db/drift_web_gate.dart`). Mismo
/// contrato que [OutboxRepository]: las filas `pending`/`attention`
/// sobreviven a recargas y se reintentan igual.
class PrefsOutboxRepository implements OutboxSource {
  final StreamController<List<OutboxRow>> _changes =
      StreamController<List<OutboxRow>>.broadcast();

  /// Cache en memoria; `localStorage` es la persistencia entre sesiones.
  List<OutboxRow>? _rows;

  Future<List<OutboxRow>> _load() async {
    final cached = _rows;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kRowsKey);
    final rows = <OutboxRow>[];
    try {
      if (raw != null && raw.isNotEmpty) {
        for (final e in (jsonDecode(raw) as List<dynamic>).whereType<Map>()) {
          rows.add(OutboxRow(
            localId: (e['localId'] as num?)?.toInt() ?? 0,
            idempotencyKey: e['idempotencyKey'] as String? ?? '',
            payload: Map<String, dynamic>.from(e['payload'] as Map? ?? {}),
            status: e['status'] as String? ?? outboxStatusPending,
            errorCode: e['errorCode'] as String?,
            errorMessage: e['errorMessage'] as String?,
            errorDetails: e['errorDetails'] is Map
                ? Map<String, dynamic>.from(e['errorDetails'] as Map)
                : null,
            attempts: (e['attempts'] as num?)?.toInt() ?? 0,
            createdAt: DateTime.tryParse(e['createdAt']?.toString() ?? '') ??
                DateTime.now(),
          ));
        }
      }
    } catch (_) {
      // JSON corrupto: se arranca vacío (no romper el POS por la cola).
      rows.clear();
    }
    rows.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _rows = rows;
    return rows;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRowsKey, jsonEncode([
      for (final r in _rows ?? const <OutboxRow>[])
        {
          'localId': r.localId,
          'idempotencyKey': r.idempotencyKey,
          'payload': r.payload,
          'status': r.status,
          'errorCode': r.errorCode,
          'errorMessage': r.errorMessage,
          'errorDetails': r.errorDetails,
          'attempts': r.attempts,
          'createdAt': r.createdAt.toIso8601String(),
        },
    ]));
  }

  void _emit() {
    if (!_changes.isClosed) {
      _changes.add(List.unmodifiable(_rows ?? const <OutboxRow>[]));
    }
  }

  OutboxRow? _row(int localId) {
    for (final r in _rows ?? const <OutboxRow>[]) {
      if (r.localId == localId) return r;
    }
    return null;
  }

  void _replace(OutboxRow row) {
    final rows = _rows!;
    final index = rows.indexWhere((r) => r.localId == row.localId);
    if (index != -1) rows[index] = row;
  }

  @override
  Future<int> enqueue({
    required String idempotencyKey,
    required Map<String, dynamic> payload,
  }) async {
    final rows = await _load();
    final nextId = rows.isEmpty
        ? 1
        : rows.map((r) => r.localId).reduce((a, b) => a > b ? a : b) + 1;
    rows.add(OutboxRow(
      localId: nextId,
      idempotencyKey: idempotencyKey,
      payload: payload,
      status: outboxStatusPending,
      attempts: 0,
      createdAt: DateTime.now(),
    ));
    rows.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    await _persist();
    _emit();
    return nextId;
  }

  @override
  Future<OutboxRow?> getById(int localId) async {
    final rows = await _load();
    for (final r in rows) {
      if (r.localId == localId) return r;
    }
    return null;
  }

  @override
  Future<List<OutboxRow>> listByStatus(String status) async {
    final rows = await _load();
    return [for (final r in rows) if (r.status == status) r];
  }

  @override
  Future<void> markAttention(
    int localId, {
    required String? code,
    required String message,
    String? detailsJson,
  }) async {
    await _load();
    final row = _row(localId);
    if (row == null) return;
    Map<String, dynamic>? details;
    if (detailsJson != null) {
      try {
        final decoded = jsonDecode(detailsJson);
        if (decoded is Map) details = Map<String, dynamic>.from(decoded);
      } catch (_) {
        details = null;
      }
    }
    _replace(OutboxRow(
      localId: row.localId,
      idempotencyKey: row.idempotencyKey,
      payload: row.payload,
      status: outboxStatusAttention,
      errorCode: code,
      errorMessage: message,
      errorDetails: details,
      attempts: row.attempts,
      createdAt: row.createdAt,
    ));
    await _persist();
    _emit();
  }

  @override
  Future<void> bumpAttempt(int localId) async {
    await _load();
    final row = _row(localId);
    if (row == null) return;
    _replace(OutboxRow(
      localId: row.localId,
      idempotencyKey: row.idempotencyKey,
      payload: row.payload,
      status: row.status,
      errorCode: row.errorCode,
      errorMessage: row.errorMessage,
      errorDetails: row.errorDetails,
      attempts: row.attempts + 1,
      createdAt: row.createdAt,
    ));
    await _persist();
    _emit();
  }

  @override
  Future<void> resetForRetry(int localId, {String? payloadJson}) async {
    await _load();
    final row = _row(localId);
    if (row == null) return;
    var payload = row.payload;
    if (payloadJson != null) {
      try {
        final decoded = jsonDecode(payloadJson);
        if (decoded is Map) payload = Map<String, dynamic>.from(decoded);
      } catch (_) {
        // Payload ilegible: se conserva el anterior (igual que el UPDATE
        // con `payload` ausente de la versión SQL).
      }
    }
    _replace(OutboxRow(
      localId: row.localId,
      idempotencyKey: row.idempotencyKey,
      payload: payload,
      status: outboxStatusPending,
      attempts: row.attempts,
      createdAt: row.createdAt,
    ));
    await _persist();
    _emit();
  }

  @override
  Future<void> delete(int localId) async {
    final rows = await _load();
    rows.removeWhere((r) => r.localId == localId);
    await _persist();
    _emit();
  }

  @override
  Stream<List<OutboxRow>> watchAll() async* {
    // Primero el estado actual y después cada mutación (broadcast).
    yield List.unmodifiable(await _load());
    yield* _changes.stream;
  }
}
