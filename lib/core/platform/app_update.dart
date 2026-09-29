import 'app_update_stub.dart'
    if (dart.library.js_interop) 'app_update_web.dart' as impl;

/// Resultado de [AppUpdate.clearServiceWorkerCaches].
///
/// [unregistered] y [deleted] cuentan cuántos service workers se desregistraron
/// y cuántas entradas de Cache Storage se borraron; sirven para confirmar que
/// la limpieza ocurrió de verdad y no se reporta un éxito vacío.
class AppUpdateOutcome {
  const AppUpdateOutcome({
    required this.ok,
    this.unregistered = 0,
    this.deleted = 0,
    this.error,
  });

  const AppUpdateOutcome.unsupported()
      : ok = false,
        unregistered = 0,
        deleted = 0,
        error = 'unsupported';

  final bool ok;
  final int unregistered;
  final int deleted;
  final String? error;
}

/// Operaciones para forzar a la webapp instalada a descargar la versión más
/// reciente del servidor.
///
/// Flutter Web registra un service worker que sirve el bundle cacheado. Tras
/// desplegar una versión nueva, ese worker puede seguir respondiendo con el
/// bundle antiguo y la app se queda "congelada" en una versión vieja; recargar
/// no basta mientras el worker siga registrado y controlando la página.
///
/// La limpieza va en dos pasos: primero se desregistran los service workers y
/// se borra el Cache Storage, y solo después se navega de nuevo. Ver
/// `web/app_update.js` para el detalle.
class AppUpdate {
  const AppUpdate._();

  /// Si la plataforma actual soporta la actualización forzada (solo web).
  static bool get isSupported => impl.isAppUpdateSupported();

  /// Desregistra los service workers y borra el Cache Storage.
  static Future<AppUpdateOutcome> clearServiceWorkerCaches() =>
      impl.clearServiceWorkerCaches();

  /// Fuerza una recarga con un parámetro anti-caché en la URL.
  static void reload() => impl.reload();
}

