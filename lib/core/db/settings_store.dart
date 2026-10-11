import 'app_database.dart';

/// Pares clave/valor de la base local (cachés pequeñas).
class SettingsStore {
  final AppDatabase _db;

  SettingsStore(this._db);

  Future<String?> get(String key) async {
    final row = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String value) async {
    await _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(AppSetting(key: key, value: value));
  }
}
