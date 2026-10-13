import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/cart_item_model.dart';
import 'cart_store.dart';

const String _kCartKey = 'pos_cart_rows_v1';

/// Carrito persistido en `localStorage` para los navegadores donde no corre
/// el wasm de drift (ver `core/db/drift_web_gate.dart`). Mismo contrato que
/// [CartStore]: escritura replace-all del carrito completo como JSON.
class PrefsCartStore implements CartPersistence {
  @override
  Future<List<CartItem>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCartKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final e in list.whereType<Map<String, dynamic>>())
          CartItem(
            variationId: (e['variationId'] as num?)?.toInt() ?? 0,
            productName: e['productName'] as String? ?? '',
            price: (e['price'] as num?)?.toDouble() ?? 0,
            quantity: (e['quantity'] as num?)?.toInt() ?? 0,
            maxStock: (e['maxStock'] as num?)?.toInt() ?? 0,
          ),
      ];
    } catch (_) {
      // JSON corrupto u otro fallo: carrito vacío (mejor que romper el POS).
      return [];
    }
  }

  @override
  Future<void> saveAll(List<CartItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCartKey, jsonEncode([
      for (final i in items)
        {
          'variationId': i.variationId,
          'productName': i.productName,
          'price': i.price,
          'quantity': i.quantity,
          'maxStock': i.maxStock,
        },
    ]));
  }
}
