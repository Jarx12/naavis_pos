import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/providers/auth_provider.dart';
import '../../sync/data/sync_service.dart';
import 'outbox_repository.dart';

/// Resultado de enviar una orden por la cola.
enum OutboxOutcome {
  /// El server la creó (o hizo replay de la misma idempotency-key).
  sent,

  /// Sin conexión (o error transitorio): queda `pending` y se reintentará
  /// sola; la venta YA quedó registrada localmente.
  waiting,

  /// Rechazo de negocio (4xx): queda `attention`; el cajero debe editarla
  /// o descartarla. Jamás se reenvía sola.
  attention,
}

class SubmitResult {
  final OutboxOutcome outcome;
  final int localId;
  final int? orderId;
  final String? totalBs;
  final String? errorCode;
  final String? errorMessage;
  final Map<String, dynamic>? errorDetails;

  const SubmitResult({
    required this.outcome,
    required this.localId,
    this.orderId,
    this.totalBs,
    this.errorCode,
    this.errorMessage,
    this.errorDetails,
  });
}

enum OutboxEventKind { sent, queued, attention }

class OutboxEvent {
  /// Contador monótono: permite que escuchas reaccionen aunque el
  /// contenido del evento se repita.
  final int seq;
  final OutboxEventKind kind;
  final int localId;
  final int? orderId;
  final String? totalBs;
  final String? errorCode;
  final String? errorMessage;
  final Map<String, dynamic>? errorDetails;

  const OutboxEvent({
    required this.seq,
    required this.kind,
    required this.localId,
    this.orderId,
    this.totalBs,
    this.errorCode,
    this.errorMessage,
    this.errorDetails,
  });
}

/// Cola de órdenes offline: SIEMPRE se encola con `Idempotency-Key`
/// generada al encolar y se intenta enviar de inmediato. Si no hay red,
/// la fila queda `pending` con auto-reintento periódico; si el server la
/// rechaza por negocio, queda `attention` a merced del cajero.
class OutboxService {
  final Dio _dio;
  final OutboxRepository _repo;
  final void Function(OutboxEvent event)? onEvent;
  final void Function()? onOrderSent;

  OutboxService(this._dio, this._repo, {this.onEvent, this.onOrderSent});

  Timer? _retryTimer;
  bool _flushing = false;
  int _seq = 0;

  /// Reintentos automáticos mientras haya filas `pending`.
  static const _retryInterval = Duration(seconds: 30);

  /// Encola la orden (con clave idempotente nueva) e intenta enviarla ya.
  Future<SubmitResult> submit(Map<String, dynamic> payload) async {
    final localId = await _repo.enqueue(
      idempotencyKey: OutboxRepository.newIdempotencyKey(),
      payload: payload,
    );
    final row = await _repo.getById(localId);
    if (row == null) {
      return SubmitResult(
        outcome: OutboxOutcome.attention,
        localId: localId,
        errorMessage: 'No se pudo guardar la orden localmente.',
      );
    }
    // emit:false: el llamador (checkout) interpreta el resultado y muestra
    // su propio SnackBar; los eventos son para los reenvíos de fondo.
    final result = await _flushRow(row, emit: false);
    _scheduleRetryIfNeeded();
    return result;
  }

  /// Barre todas las filas `pending` (los `attention` no se tocan).
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final pending = await _repo.listByStatus(outboxStatusPending);
      for (final row in pending) {
        await _flushRow(row, emit: true);
      }
    } catch (_) {
      // Un fallo inesperado no debe tumbar el timer: se reintenta después.
    } finally {
      _flushing = false;
      _scheduleRetryIfNeeded();
    }
  }

  Future<SubmitResult> _flushRow(OutboxRow row, {required bool emit}) async {
    try {
      final response = await _dio.post(
        '/orders',
        data: row.payload,
        options: Options(headers: {'Idempotency-Key': row.idempotencyKey}),
      );
      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : null;

      await _repo.delete(row.localId);
      final orderId = data?['id'] is int ? data!['id'] as int : null;
      final totalBs = data?['total_bs']?.toString();
      onOrderSent?.call(); // el catálogo local debe refrescar su stock
      if (emit) {
        _emit(OutboxEvent(
          seq: ++_seq,
          kind: OutboxEventKind.sent,
          localId: row.localId,
          orderId: orderId,
          totalBs: totalBs,
        ));
      }
      return SubmitResult(
        outcome: OutboxOutcome.sent,
        localId: row.localId,
        orderId: orderId,
        totalBs: totalBs,
      );
    } on DioException catch (e) {
      return _classifyError(row, e, emit: emit);
    }
  }

  /// Traduce la respuesta de error del server a una decisión de la cola.
  ///
  /// Contrato del backend (`errors.py`):
  /// - `error.retryable == true` o 429/5xx → reintentar después.
  /// - 4xx de negocio (`INSUFFICIENT_STOCK`, `COUPON_*`…) → atención.
  /// - Sin respuesta HTTP → sin conexión, reintentar.
  /// - 401/403 → auth (el interceptor ya intentó refrescar); se conserva
  ///   pendiente: se resolverá al re-login y el siguiente flush la saca.
  Future<SubmitResult> _classifyError(
    OutboxRow row,
    DioException e, {
    required bool emit,
  }) async {
    final response = e.response;
    if (response == null) {
      // Sin conexión: sigue pending; el timer / la vuelta de la red la sacan.
      await _repo.bumpAttempt(row.localId);
      _scheduleRetryIfNeeded();
      return SubmitResult(outcome: OutboxOutcome.waiting, localId: row.localId);
    }

    final status = response.statusCode ?? 0;
    final body = response.data is Map ? response.data as Map : null;
    final err = body?['error'] is Map ? body!['error'] as Map : null;

    final code = err?['code']?.toString();
    final message = err?['message']?.toString() ??
        body?['detail']?.toString() ??
        'El server rechazó la orden (HTTP $status).';
    final retryable = err?['retryable'];
    final details = err?['details'];

    final isAuthIssue = status == 401 || status == 403;
    final isRetryable = retryable == true ||
        status == 429 ||
        (status >= 500 && retryable == null);

    if (isAuthIssue || isRetryable) {
      // Silencioso: solo queda pending; no se molesta al cajero.
      await _repo.bumpAttempt(row.localId);
      _scheduleRetryIfNeeded();
      return SubmitResult(
        outcome: OutboxOutcome.waiting,
        localId: row.localId,
        errorCode: code,
        errorMessage: message,
      );
    }

    // Rechazo de negocio: queda `attention` y NUNCA se reenvía sola.
    await _repo.markAttention(
      row.localId,
      code: code,
      message: message,
      detailsJson: details != null ? jsonEncode(details) : null,
    );
    if (emit) {
      _emit(OutboxEvent(
        seq: ++_seq,
        kind: OutboxEventKind.attention,
        localId: row.localId,
        errorCode: code,
        errorMessage: message,
        errorDetails:
            details is Map ? Map<String, dynamic>.from(details) : null,
      ));
    }
    return SubmitResult(
      outcome: OutboxOutcome.attention,
      localId: row.localId,
      errorCode: code,
      errorMessage: message,
      errorDetails: details is Map ? Map<String, dynamic>.from(details) : null,
    );
  }

  // ── Acciones del cajero sobre filas `attention` ───────────────────

  /// Fila actual (para poblar el diálogo de edición).
  Future<OutboxRow?> getRow(int localId) => _repo.getById(localId);

  /// Reintenta a mano una fila `pending` (botón "Reintentar ahora").
  Future<void> retryNow(int localId) async {
    final row = await _repo.getById(localId);
    if (row == null || row.needsAttention) return;
    await _flushRow(row, emit: true);
    _scheduleRetryIfNeeded();
  }

  /// Descarta una orden local (nunca llegó al server, o el cajero decidió
  /// no reenviarla). Se usa también cuando la edición vaciaría los ítems.
  Future<void> discard(int localId) async {
    await _repo.delete(localId);
  }

  /// El cajero editó la orden en el diálogo de conflicto: payload nuevo,
  /// vuelta a `pending` y reintento inmediato con la MISMA clave
  /// idempotente (seguro: un 409 nunca crea la orden).
  Future<SubmitResult> saveEditAndRetry(
    int localId,
    Map<String, dynamic> payload,
  ) async {
    await _repo.resetForRetry(localId, payloadJson: jsonEncode(payload));
    final row = await _repo.getById(localId);
    if (row == null) {
      return SubmitResult(
        outcome: OutboxOutcome.attention,
        localId: localId,
        errorMessage: 'La orden dejó de existir en la cola.',
      );
    }
    final result = await _flushRow(row, emit: false);
    _scheduleRetryIfNeeded();
    return result;
  }

  // ── Internos ──────────────────────────────────────────────────────

  void _emit(OutboxEvent event) {
    try {
      onEvent?.call(event);
    } catch (_) {
      // Una escucha caída no debe romper el envío.
    }
  }

  void _scheduleRetryIfNeeded() {
    if (_retryTimer != null) return;
    unawaited(() async {
      try {
        final pending = await _repo.listByStatus(outboxStatusPending);
        if (pending.isEmpty) return;
      } catch (_) {
        return;
      }
      _retryTimer = Timer(_retryInterval, () {
        _retryTimer = null;
        flush();
      });
    }());
  }

  void dispose() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }
}

// ── Providers ─────────────────────────────────────────────────────

/// Último evento de la cola (enviada / en espera / requiere atención).
/// La UI lo escucha con `ref.listen` para reaccionar a los reenvíos de
/// fondo (flush por timer o por vuelta de la red).
class OutboxEventNotifier extends Notifier<OutboxEvent?> {
  @override
  OutboxEvent? build() => null;

  void emit(OutboxEvent event) => state = event;
}

final outboxEventProvider =
    NotifierProvider<OutboxEventNotifier, OutboxEvent?>(
        OutboxEventNotifier.new);

/// Filas vivas de la cola (pending + attention): alimenta el badge de la
/// app bar y la hoja de órdenes pendientes.
final outboxRowsProvider = StreamProvider<List<OutboxRow>>(
  (ref) => ref.watch(outboxRepositoryProvider).watchAll(),
);

final outboxServiceProvider = Provider<OutboxService>((ref) {
  final service = OutboxService(
    ref.watch(dioClientProvider).dio,
    ref.watch(outboxRepositoryProvider),
    onEvent: (event) {
      try {
        ref.read(outboxEventProvider.notifier).emit(event);
      } catch (_) {}
    },
    onOrderSent: () {
      // Stock recién descontado en el server: delta en segundo plano.
      try {
        ref.read(syncServiceProvider).sync();
      } catch (_) {}
    },
  );
  ref.onDispose(service.dispose);
  return service;
});

