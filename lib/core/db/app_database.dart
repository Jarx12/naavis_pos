import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Catálogo: categorías del servidor.
///
/// Los nombres se resuelven SIEMPRE contra esta tabla (join local) y nunca
/// contra la lista embebida en cada producto del payload de sync: esa lista
/// viaja como copia y queda obsoleta al renombrar una categoría. La lista
/// embebida solo aporta los ids.
class Categories extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Catálogo: productos (payload completo de `ProductDetailOut`, sin los
/// hijos: variantes/imágenes/categorías viven en sus propias tablas).
class Products extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  RealColumn get price => real()();
  RealColumn get finalPrice => real()();
  IntColumn get discountPercentage => integer()();
  TextColumn get description => text()();
  IntColumn get totalStock => integer()();
  RealColumn get cost => real()();
  BoolColumn get isVisible => boolean()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Join N:M producto↔categoría (se purga al recibir `deleted_categories`).
class ProductCategories extends Table {
  IntColumn get productId => integer()();
  IntColumn get categoryId => integer()();

  @override
  Set<Column> get primaryKey => {productId, categoryId};
}

class Variations extends Table {
  IntColumn get id => integer()();
  IntColumn get productId => integer()();
  TextColumn get variationType => text()();
  IntColumn get stock => integer()();
  TextColumn get searchTags => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class ProductImages extends Table {
  IntColumn get id => integer()();
  IntColumn get productId => integer()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get thumbnailUrl => text().nullable()();
  BoolColumn get isMain => boolean().withDefault(const Constant(false))();

  /// Variantes asociadas a la foto como JSON "[452,453]" (API:
  /// `variation_ids`). Vacío = foto general del producto.
  TextColumn get variationIds => text().withDefault(const Constant('[]'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cursor de sincronización: una sola fila (id=1).
///
/// `serverTime` es el `server_time` de la PRIMERA página del último delta
/// aplicado (o del seed). Se guarda en crudo tal cual lo devuelve el server
/// para reenviarlo como parámetro `since` sin reinterpretar el formato.
class SyncState extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get serverTime => text().nullable()();
  BoolColumn get seeded => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Carrito persistido: sobrevive a reinicios de la app y a cortes de red.
class CartRows extends Table {
  IntColumn get variationId => integer()();
  TextColumn get productName => text()();
  RealColumn get price => real()();
  IntColumn get quantity => integer()();
  IntColumn get maxStock => integer()();

  @override
  Set<Column> get primaryKey => {variationId};
}

/// Cola de órdenes fuera de línea. Solo viven filas `pending` y `attention`;
/// al confirmarse o descartarse se eliminan.
///
/// - `pending`: se reintentará sola (error de red / 5xx / 429).
/// - `attention`: el server rechazó la orden por regla de negocio
///   (p.ej. `INSUFFICIENT_STOCK`); NUNCA se reenvía sola: el cajero debe
///   editarla o descartarla desde la hoja de órdenes.
class OutboxOrders extends Table {
  IntColumn get localId => integer().autoIncrement()();
  TextColumn get idempotencyKey => text().unique()();
  TextColumn get payload => text()(); // JSON de CreateOrderIn.toJson()
  TextColumn get status => text()();
  TextColumn get errorCode => text().nullable()();
  TextColumn get errorMessage => text().nullable()();
  TextColumn get errorDetails => text().nullable()(); // JSON o null
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
}

/// Pares clave/valor para cachés pequeñas (tasa de cambio, etc.).
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [
  Categories,
  Products,
  ProductCategories,
  Variations,
  ProductImages,
  SyncState,
  CartRows,
  OutboxOrders,
  AppSettings,
])
class AppDatabase extends _$AppDatabase {
  // Constructor para tests (base en memoria, `AppDatabase(NativeDatabase.memory())`).
  AppDatabase(super.e);

  /// Abre la base en la plataforma actual.
  ///
  /// `web` es obligatorio en la PWA: sin él `driftDatabase` lanza
  /// "When compiling to the web, the 'web' parameter needs to be set" al
  /// primer acceso (se ignora en nativo). Las URIs son relativas al
  /// `<base href>` del build (`/pos/` en producción) y apuntan a los
  /// archivos que `flutter build web` copia desde `web/`.
  AppDatabase.defaults()
      : super(
          driftDatabase(
            name: 'naavis_pos',
            web: DriftWebOptions(
              sqlite3Wasm: Uri.parse('sqlite3.wasm'),
              driftWorker: Uri.parse('drift_worker.js'),
            ),
          ),
        );

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v2: la asociación foto↔variante se persiste por primera vez.
            await m.addColumn(productImages, productImages.variationIds);
            // El delta anterior guardó las fotos SIN esta asociación y el
            // cursor ya avanzó (el server no reenvía ese producto hasta que
            // cambie): se limpia el cursor para que el próximo arranque haga
            // un seed completo y las imágenes vuelvan con sus variation_ids.
            await delete(syncState).go();
          }
        },
      );
}
