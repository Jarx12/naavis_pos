import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/dio_client.dart';
import '../../data/auth_repository.dart';
import '../../domain/auth_model.dart';
import '../../../../core/config/app_config.dart';

class AuthState {
  final bool isLoading;
  final AuthTokens? tokens;
  final String? error;

  AuthState({this.isLoading = false, this.tokens, this.error});

  bool get isAuthenticated => tokens != null && tokens!.access.isNotEmpty;
}

class AuthNotifier extends Notifier<AuthState> {
  late final AuthRepository _repository;

  @override
  AuthState build() {
    final baseDio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    _repository = AuthRepository(baseDio);

    // Intentar restaurar sesión persistida al inicializar el provider
    _restoreSession();

    return AuthState(isLoading: true);
  }

  // Cargar tokens guardados en disco
  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final access = prefs.getString('access_token');
      final refresh = prefs.getString('refresh_token');

      if (access != null && refresh != null) {
        state = AuthState(
          tokens: AuthTokens(access: access, refresh: refresh),
        );
      } else {
        state = AuthState();
      }
    } catch (_) {
      state = AuthState();
    }
  }

  // Login de usuario
  Future<bool> login(String username, String password) async {
    state = AuthState(isLoading: true);
    try {
      final tokens = await _repository.login(username, password);
      await _saveTokens(tokens);
      state = AuthState(tokens: tokens);
      return true;
    } catch (e) {
      state = AuthState(error: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  // Actualizar tokens tras una rotación/refresco exitoso
  Future<void> updateTokens(AuthTokens newTokens) async {
    await _saveTokens(newTokens);
    state = AuthState(tokens: newTokens);
  }

  // Helper para persistir en disco
  Future<void> _saveTokens(AuthTokens tokens) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', tokens.access);
    await prefs.setString('refresh_token', tokens.refresh);
  }

  // Cierre de Sesión Explícito
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    state = AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

final authTokenProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).tokens?.access;
});

final dioClientProvider = Provider((ref) => DioClient(ref));