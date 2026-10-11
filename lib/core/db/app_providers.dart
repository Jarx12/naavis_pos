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
