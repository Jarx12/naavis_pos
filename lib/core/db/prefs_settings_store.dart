import 'package:shared_preferences/shared_preferences.dart';

import 'settings_store.dart';

/// Par clave/valor en `localStorage` para los navegadores donde no corre el
/// wasm de drift (ver `core/db/drift_web_gate.dart`). Las clases se
/// prefijan para no chocar con las prefs de la UI (tokens, toggles…).
class PrefsSettingsStore implements KeyValueStore {
  static const String _prefix = 'pos_setting_';

  @override
  Future<String?> get(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_prefix$key');
  }

  @override
  Future<void> set(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$key', value);
  }
}
