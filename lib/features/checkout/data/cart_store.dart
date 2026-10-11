import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/app_providers.dart';
import '../domain/cart_item_model.dart';

/// Persistencia del carrito en la base local: sobrevive a reinicios y
/// cortes de red. La escritura es replace-all (el carrito es chico).
class CartStore {
  final AppDatabase _db;

  CartStore(this._db);

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

final cartStoreProvider = Provider<CartStore>(
  (ref) => CartStore(ref.watch(appDatabaseProvider)),
);
