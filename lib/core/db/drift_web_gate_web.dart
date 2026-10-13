import 'dart:js_interop';
import 'dart:typed_data';

/// Módulo wasm mínimo que USA extended-const: un global i32 con init
/// `i32.const 1; i32.const 2; i32.add; end`. Safari < 17.2 lo rechaza.
const List<int> _extendedConstModule = <int>[
  0, 97, 115, 109, 1, 0, 0, 0, // magic + version
  6, 9, 1, 127, 0, 65, 1, 65, 2, 106, 11, // global section (1 global i32)
];

@JS('WebAssembly.validate')
external bool _validate(JSAny moduleBytes);

/// true si el navegador valida el probe sintético de extended-const.
bool supportsExtendedConst() {
  try {
    return _validate(Uint8List.fromList(_extendedConstModule).toJS);
  } catch (_) {
    return false;
  }
}

/// Valida un módulo wasm real (p. ej. `sqlite3.wasm`) sin instanciarlo.
bool validateWasmModule(List<int> bytes) {
  try {
    return _validate(Uint8List.fromList(bytes).toJS);
  } catch (_) {
    return false;
  }
}
