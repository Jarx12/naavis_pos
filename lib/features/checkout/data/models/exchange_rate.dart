import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/settings_store.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// Modelo para la respuesta de /exchange-rate/current
class ExchangeRate {
  final String currency;
  final double rate;
  final DateTime updatedAt;

  ExchangeRate({
    required this.currency,
    required this.rate,
    required this.updatedAt,
  });

  factory ExchangeRate.fromJson(Map<String, dynamic> json) {
    return ExchangeRate(
      currency: json['currency'] ?? 'USD_VES',
      rate: (json['rate'] as num).toDouble(),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'currency': currency,
        'rate': rate,
        'updated_at': updatedAt.toIso8601String(),
      };

  /// true si la caché local tiene más de 24 h (para el chip de aviso).
  bool get isStale =>
      DateTime.now().difference(updatedAt) > const Duration(hours: 24);
}

const String _rateCacheKey = 'exchange_rate_cache';

/// Tasa de cambio caché-first:
/// 1. Si hay caché local, se muestra YA (sin esperar red) y se refresca en
///    segundo plano; si la red falla, se conserva la caché.
/// 2. Sin caché (primer arranque), se espera a la red.
///
/// El server siempre gana: el valor fresco es el que se guarda y el que se
/// usa al confirmar la orden (el backend calcula el `exchange_rate` final).
class ExchangeRateNotifier extends AsyncNotifier<ExchangeRate> {
  @override
  Future<ExchangeRate> build() async {
    final settings = ref.watch(settingsStoreProvider);
    final cached = await _readCache(settings);

    if (cached != null) {
      _refreshInBackground(settings);
      return cached;
    }
    return _fetch(settings);
  }

  Future<ExchangeRate?> _readCache(KeyValueStore settings) async {
    try {
      final raw = await settings.get(_rateCacheKey);
      if (raw == null) return null;
      return ExchangeRate.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<ExchangeRate> _fetch(KeyValueStore settings) async {
    final dioClient = ref.read(dioClientProvider);
    final response = await dioClient.dio.get('/exchange-rate/current');
    final rate = ExchangeRate.fromJson(response.data as Map<String, dynamic>);
    try {
      await settings.set(_rateCacheKey, jsonEncode(rate.toJson()));
    } catch (_) {
      // Best-effort: si la caché no se puede guardar, igual sirve en vivo.
    }
    return rate;
  }

  Future<void> _refreshInBackground(KeyValueStore settings) async {
    try {
      final fresh = await _fetch(settings);
      if (ref.mounted) state = AsyncData(fresh);
    } catch (_) {
      // Sin red (o el server falló): se queda la caché; el chip de >24 h
      // avisa si corresponde.
    }
  }
}

// Tasa del backend con caché local (se muestra al instante si hay red caída)
final currentExchangeRateProvider =
    AsyncNotifierProvider<ExchangeRateNotifier, ExchangeRate>(
        ExchangeRateNotifier.new);