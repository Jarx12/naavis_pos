/// Non-web stub: fuera de la web no hay wasm que validar; el gate en
/// `app_providers.dart` resuelve true por kIsWeb antes de llegar aquí.
///
/// Mismas firmas que `drift_web_gate_web.dart`.
bool supportsExtendedConst() => true;

bool validateWasmModule(List<int> bytes) => true;
