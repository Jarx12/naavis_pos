import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Conectividad deducida de los resultados REALES de Dio (sin dependencias
/// extra): toda respuesta HTTP marca `online`; un error sin respuesta
/// (timeout de conexión, socket caído) marca `offline`.
///
/// `unknown` = aún no ha habido tráfico en esta sesión.
enum ConnectivityState { unknown, online, offline }

class ConnectivityNotifier extends Notifier<ConnectivityState> {
  @override
  ConnectivityState build() => ConnectivityState.unknown;

  void markOnline() {
    if (state != ConnectivityState.online) {
      state = ConnectivityState.online;
    }
  }

  void markOffline() {
    if (state != ConnectivityState.offline) {
      state = ConnectivityState.offline;
    }
  }
}

final connectivityProvider =
    NotifierProvider<ConnectivityNotifier, ConnectivityState>(
        ConnectivityNotifier.new);
