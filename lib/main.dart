import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/db/app_providers.dart';
import 'core/db/drift_web_gate.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/checkout/presentation/pos_screen.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // En web, decidir ANTES de runApp si el navegador puede compilar el
    // sqlite3.wasm de drift; si no, la app entera usa el modo respaldo
    // online-only (ver core/db/drift_web_gate.dart). En nativo es gratis.
    final driftOk = await _storageGate();

    runApp(
      ProviderScope(
        overrides: [driftStorageAvailableProvider.overrideWithValue(driftOk)],
        child: const MyApp(),
      ),
    );
  }, (error, stackTrace) {});
}

/// Nunca puede lanzar: ante la duda, en web se prefiere el modo memoria
/// (funciona en cualquier navegador) antes que arriesgar drift colgado.
Future<bool> _storageGate() async {
  try {
    return await isDriftWebUsable();
  } catch (_) {
    return !kIsWeb;
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    return MaterialApp(
      title: 'NaaviS - SPV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: authState.isLoading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : authState.isAuthenticated
              ? const PosScreen()
              : const LoginScreen(),
    );
  }
}