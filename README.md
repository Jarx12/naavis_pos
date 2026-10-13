# Naavis POS

A Flutter project to provide a frontend to a DJANGO Based RESTful API in a e-commerce setting.

## Offline / caché local (drift)

El POS funciona con **caché local + delta sync** sobre el endpoint
`GET /api/v1/sync/catalog`:

- **Catálogo local** (`lib/core/db/app_database.dart`): productos,
  variantes, imágenes, joins categoría; la copia en cada producto solo aporta ids, así
  un rename en el server no queda congelado en el cliente). El cursor de
  sync (`server_time`) se guarda en la tabla `sync_state`.
  - Seed completo en la primera ejecución; deltas con `since=<cursor>` a
    partir de ahí.
  - Tombstones (`deleted_*`) aplicadas antes que los payloads, con purga de los joins de categorías borradas.
- **Carrito persistente** en `cart_rows`.
- **Tasa de cambio** cacheada en `app_settings` con indicador si tiene >24 h.
- **Cola de órdenes offline** (`outbox_orders`): toda orden se encola con
  una `Idempotency-Key` y se intenta enviar.
  - Sin red → `pending` + auto-reintento (30 s, al volver la conexión y
    al abrir el POS); la venta queda registrada localmente.
  - Rechazo → (`INSUFFICIENT_STOCK`, `COUPON_*`…) → `attention`:
    **No se reenvía sola**; el usuario la edita o la descarta desde el badge "Órdenes fuera de
    línea" de la app bar.
- **Sin cupones offline**
- **Toggles de visualización**: mostrar productos ocultos y/o agotados
  apagados

### Web (PWA)

La base en web usa WASM: `web/sqlite3.wasm` y `web/drift_worker.js`.
Antes de arrancar, `main()` valida que el navegador pueda compilar ese
wasm (`core/db/drift_web_gate.dart`: probe sintético de `extended-const`
+ una vez `WebAssembly.validate` del binario real). Los navegadores que
no puedan — abren un modo **online-only**: catálogo solo en memoria
(seed completo por sesión) y carrito/cola de órdenes/cachés en
`localStorage`. El cliente nativo siempre usa drift con offline completo.

### Caché de imágenes

Dos capas, una por plataforma:

- **App (nativo)**: `cached_network_image` con `PosImageCacheManager`
  (`lib/core/images/pos_image_cache.dart`) guarda las fotos en disco
  (LRU de 500 archivos, revalida a los 30 días). Además, cada sync
  exitosa precachéa en segundo plano las fotos del catálogo local
  (`CatalogImagePrefetcher`, mejor esfuerzo y sin bloquear la sync),
  así el cajero no espera la primera descarga al ver un producto. La
  tarjeta del grid decodifica a 600px de ancho (`memCacheWidth`); el
  visor usa el original a tamaño completo para el zoom.
- **Web (PWA)**: las imágenes usan `Image.network` (sin
  `cached_network_image`, que no cachea en web); el navegador cachea
  `/media/` según las cabeceras de nginx.


### Comandos

```bash
flutter pub get
dart run build_runner build
flutter analyze
flutter test
```


