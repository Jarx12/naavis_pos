import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/app_providers.dart';
import '../domain/cart_item_model.dart';
import 'prefs_cart_store.dart';

/// Persistencia del carrito. Dos implementaciones:
/// - [CartStore] (Drift): nativo y web con wasm compatible.
/// - [PrefsCartStore]: navegadores viejos, JSON en `localStorage`.
abstract class CartPersistence {
  Future<List<CartItem>> load();

  Future<void> saveAll(List<CartItem> items);
}

/// Persistencia del carrito en la base local: sobrevive a reinicios y
/// cortes de red. La escritura es replace-all (el carrito es chico).
class CartStore implements CartPersistence {
  final AppDatabase _db;

  CartStore(this._db);

  @override
  Future<List<CartItem>> load() async {
    final rows = await _db.select(_db.cartRows).get();
    return [
      for (final r in rows)
        CartItem(
          variationId: r.variationId,
          productName: r.productName,
          price: r.price,
          quantity: r.quantity,
          maxStock: r.maxStock,
        ),
    ];
  }

  @override
  Future<void> saveAll(List<CartItem> items) async {
    await _db.transaction(() async {
      await _db.delete(_db.cartRows).go();
      for (final item in items) {
        await _db.into(_db.cartRows).insert(
              CartRow(
                variationId: item.variationId,
                productName: item.productName,
                price: item.price,
                quantity: item.quantity,
                maxStock: item.maxStock,
              ),
            );
      }
    });
  }
}

final cartStoreProvider = Provider<CartPersistence>((ref) {
  // Navegador sin soporte del wasm de drift: carrito en localStorage.
  if (kIsWeb && !ref.watch(driftStorageAvailableProvider)) {
    return PrefsCartStore();
  }
  return CartStore(ref.watch(appDatabaseProvider));
});
