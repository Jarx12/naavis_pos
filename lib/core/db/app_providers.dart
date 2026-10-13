import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// Base de datos local de la app (SQLite nativo / WASM en web).
///
/// Una sola instancia para toda la sesión; se cierra al descartar el scope.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.defaults();
  ref.onDispose(db.close);
  return db;
});

/// true = el almacenamiento local es Drift (nativo, o web con navegador que
/// compila `sqlite3.wasm`); false = modo respaldo online-only en web
/// (carrito/outbox en `localStorage`, catálogo solo en memoria).
///
/// Se decide en `main()` con el probe de `drift_web_gate.dart` y se inyecta
/// con un override; el default true no toca nada en nativo.
final driftStorageAvailableProvider = Provider<bool>((ref) => true);
