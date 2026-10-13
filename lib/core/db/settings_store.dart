import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'app_providers.dart';
import 'prefs_settings_store.dart';

/// Pares clave/valor del almacenamiento local (cachés pequeñas). Dos
/// implementaciones:
/// - [SettingsStore] (Drift): nativo y web con wasm compatible.
/// - [PrefsSettingsStore]: navegadores viejos, `localStorage`.
abstract class KeyValueStore {
  Future<String?> get(String key);

  Future<void> set(String key, String value);
}

/// Pares clave/valor de la base local (cachés pequeñas).
class SettingsStore implements KeyValueStore {
  final AppDatabase _db;

  SettingsStore(this._db);

  @override
  Future<String?> get(String key) async {
    final row = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  @override
  Future<void> set(String key, String value) async {
    await _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(AppSetting(key: key, value: value));
  }
}

final settingsStoreProvider = Provider<KeyValueStore>((ref) {
  // Navegador sin soporte del wasm de drift: cachés en localStorage.
  if (kIsWeb && !ref.watch(driftStorageAvailableProvider)) {
    return PrefsSettingsStore();
  }
  return SettingsStore(ref.watch(appDatabaseProvider));
});
