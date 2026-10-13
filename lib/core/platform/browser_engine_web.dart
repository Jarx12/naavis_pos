import 'dart:js_interop';

@JS('navigator.userAgent')
external String get _userAgent;

/// true si el UA anuncia Safari sin ser un navegador Chromium (esos
/// también dicen "Safari" en el UA). Los navegadores iOS (CriOS, FxiOS,
/// EdgiOS…) no traen "Chrome/" ni "Edg/" —sufijos propios— y aquí sí
/// cuentan como WebKit, que es lo que importa: iOS no permite motores
/// ajenos (hasta la DMA europea, y en iOS 15 para nada).
bool isWebKitEngine() {
  try {
    final ua = _userAgent;
    return ua.contains('Safari') &&
        !ua.contains('Chrome/') &&
        !ua.contains('Chromium') &&
        !ua.contains('Edg/') &&
        !ua.contains('OPR/') &&
        !ua.contains('SamsungBrowser');
  } catch (_) {
    return false;
  }
}
