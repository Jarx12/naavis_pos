import 'browser_engine_stub.dart'
    if (dart.library.js_interop) 'browser_engine_web.dart' as impl;

/// true si el motor del navegador es WebKit (Safari en cualquier SO y, en
/// iOS/iPadOS, TODOS los navegadores: CriOS, FxiOS, EdgiOS… comparten el
/// motor de Apple).
///
/// Fuera de la web siempre es false (nativo no aplica).
bool isWebKitEngine() => impl.isWebKitEngine();
