import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'drift_web_gate_stub.dart'
    if (dart.library.js_interop) 'drift_web_gate_web.dart' as impl;

/// Caché del resultado de la validación completa del wasm.
const String _validatedKey = 'pos_drift_wasm_validated';

/// true si esta plataforma puede usar Drift como almacenamiento local.
///
/// - Nativo: siempre true (SQLite nativo, sin wasm de por medio).
/// - Web: el navegador debe poder COMPILAR `web/sqlite3.wasm`; si no, la
///   app abre el modo online-only (ver `localCatalogProvider`). La última
///   feature requerida que entró al motor fue `extended-const` (Safari 17.2,
///   nov 2023), así que iOS/macOS Safari más viejos — p. ej. un iPhone
///   clavado en iOS 15.8 — quedan fuera de drift pero usan la app igual.
///
/// La decisión se inyecta en `driftStorageAvailableProvider` desde
/// `main()`. La validación completa del binario solo corre una vez (el
/// probe sintético de extended-const es gratis y corre siempre, así un
/// navegador viejo nunca paga ni siquiera el fetch).
Future<bool> isDriftWebUsable() async {
  if (!kIsWeb) return true;

  // Probe sintético y sincrono: módulo mínimo que USA extended-const
  // (init de un global: `i32.const 1; i32.const 2; i32.add; end`).
  // Safari < 17.2 lo rechaza; si falla, no hace falta bajar el wasm.
  if (!impl.supportsExtendedConst()) return false;

  final prefs = await SharedPreferences.getInstance();
  final cached = prefs.getBool(_validatedKey);
  if (cached != null) return cached;

  // Primera vez: validar el binario REAL de la app. `WebAssembly.validate`
  // lo dice todo (features + encoding) sin instanciar nada. Sin red se
  // confía en el probe sintético (no cachear, reintentar en el próximo
  // arranque) para no perder la continuidad del carrito.
  try {
    final response = await Dio().get<List<int>>(
      Uri.base.resolve('sqlite3.wasm').toString(),
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) return true;
    final ok = impl.validateWasmModule(bytes);
    await prefs.setBool(_validatedKey, ok);
    return ok;
  } catch (_) {
    return true;
  }
}