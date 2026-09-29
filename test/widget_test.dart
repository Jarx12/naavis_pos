import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:naavis_pos/features/auth/data/auth_repository.dart';
import 'package:naavis_pos/features/catalog/data/catalog_repository.dart';
import 'package:naavis_pos/features/catalog/domain/category_model.dart';
import 'package:naavis_pos/features/catalog/domain/product_model.dart';
import 'package:naavis_pos/features/catalog/presentation/providers/catalog_provider.dart';
import 'package:naavis_pos/features/checkout/data/models/create_order_dto.dart';
import 'package:naavis_pos/features/checkout/data/models/exchange_rate.dart';
import 'package:naavis_pos/features/checkout/domain/cart_item_model.dart';
import 'package:naavis_pos/features/checkout/presentation/checkout_screen.dart';
import 'package:naavis_pos/features/checkout/presentation/pos_screen.dart';
import 'package:naavis_pos/features/checkout/presentation/providers/cart_provider.dart';
import 'package:naavis_pos/features/checkout/presentation/widgets/cart_panel.dart';

/// Repositorio de catálogo falso: cuenta cuántas veces se piden productos.
class _FakeCatalogRepository implements CatalogRepository {
  _FakeCatalogRepository(this.onGetProducts);

  final void Function() onGetProducts;

  @override
  Future<List<ProductDetailOut>> getProducts({
    int? categoryId,
    bool onlyVisible = true,
  }) async {
    onGetProducts();
    return const [
      ProductDetailOut(
        id: 1,
        name: 'Producto de prueba',
        price: 10,
        finalPrice: 10,
        discountPercentage: 0,
        description: 'Producto de prueba',
        totalStock: 10,
        cost: 5,
        isVisible: true,
      ),
    ];
  }

  @override
  Future<List<CategoryOut>> getCategories() async => const [];
}

/// Carrito con productos, para que "PROCESAR COBRO" quede habilitado.
class _SeededCartNotifier extends CartNotifier {
  @override
  List<CartItem> build() => [
        CartItem(
          variationId: 1,
          productName: 'Producto de prueba',
          price: 10,
          quantity: 2,
          maxStock: 99,
        ),
      ];
}

/// Height of the simulated soft keyboard.
const double kKeyboardHeight = 300;

void main() {
  /// Builds the screen inside an explicit [MediaQuery] so the system insets are
  /// deterministic (independent of `tester.view` semantics).
  ///
  /// [navBarHeight] simulates the Android navigation bar (system padding).
  /// [keyboardHeight] simulates the soft keyboard (view insets).
  Widget buildScreen({
    double navBarHeight = 0,
    double keyboardHeight = 0,
  }) {
    return ProviderScope(
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                viewPadding:
                    mq.viewPadding.copyWith(bottom: navBarHeight),
                padding: mq.padding.copyWith(
                  bottom: (navBarHeight - keyboardHeight).clamp(0, double.infinity),
                ),
                viewInsets: mq.viewInsets.copyWith(bottom: keyboardHeight),
              ),
              child: CheckoutScreen(
                cartItems: [OrderItemIn(variationId: 1, quantity: 2)],
                subtotal: 50,
                currentRate: 36.5,
                onSubmitOrder: _noopSubmit,
              ),
            );
          },
        ),
      ),
    );
  }

  /// The form is the only place in this screen that scrolls.
  Finder formList() => find.descendant(
        of: find.byType(Form),
        matching: find.byType(ListView),
      );

  Finder orderButton() =>
      find.widgetWithText(ElevatedButton, 'PROCESAR ORDEN');

  /// Reproduces how `PosScreen` shows this screen: inside a
  /// `showModalBottomSheet(isScrollControlled: true, useSafeArea: true)`.
  ///
  /// Note there is NO `Padding(bottom: viewInsets.bottom)` wrapper: the
  /// `Scaffold` inside `CheckoutScreen` is solely responsible for the keyboard.
  Future<void> showInBottomSheet(
    WidgetTester tester, {
    required double keyboardHeight,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (hostContext) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showModalBottomSheet<void>(
                        context: hostContext,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder: (dialogContext) {
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(dialogContext)
                                  .viewInsets
                                  .bottom,
                            ),
                            child: CheckoutScreen(
                              cartItems: [
                                OrderItemIn(variationId: 1, quantity: 2),
                              ],
                              subtotal: 50,
                              currentRate: 36.5,
                              onSubmitOrder: _noopSubmit,
                            ),
                          );
                        },
                      );
                    },
                    child: const Text('abrir'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    // Simula la apertura del teclado.
    tester.view.viewInsets = FakeViewPadding(bottom: keyboardHeight);
    await tester.pumpAndSettle();
  }

  group('CheckoutScreen y el teclado en pantalla', () {
    testWidgets(
      'el inset del teclado NO se vuelve a sumar al padding del ListView',
      (tester) async {
        // Simula el teclado abierto.
        tester.view.viewInsets = const FakeViewPadding(bottom: kKeyboardHeight);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        final list = tester.widget<ListView>(formList());

        // El padding es fijo: si además incluyera el inset del teclado,
        // aparecería un área en blanco del tamaño del teclado tapando campos.
        expect(list.padding, const EdgeInsets.fromLTRB(16, 16, 16, 24));
      },
    );

    testWidgets(
      'el Scaffold NO descuenta el teclado (lo hace el Padding del sheet)',
      (tester) async {
        await tester.pumpWidget(buildScreen(keyboardHeight: 0));
        await tester.pumpAndSettle();

        final heightWithoutKeyboard = tester.getSize(formList()).height;

        await tester.pumpWidget(buildScreen(keyboardHeight: kKeyboardHeight));
        await tester.pumpAndSettle();

        final heightWithKeyboard = tester.getSize(formList()).height;

        // El inset del teclado se aplica UNA sola vez, en el `Padding` de
        // `showModalBottomSheet`. Si el `Scaffold` también lo descontara, el
        // formulario se quedaría sin espacio y quedaría un área en blanco del
        // tamaño del teclado tapando los campos.
        expect(
          heightWithKeyboard,
          moreOrLessEquals(heightWithoutKeyboard, epsilon: 1),
          reason: 'El Scaffold está descontando el teclado además del Padding.',
        );
      },
    );

    testWidgets(
      'el botón PROCESAR no queda bajo la barra de navegación de Android',
      (tester) async {
        // Barra de navegación Android de 48px, teclado cerrado.
        await tester.pumpWidget(buildScreen(navBarHeight: 48));
        await tester.pumpAndSettle();

        // Desplazamos hasta el final del contenido.
        await tester.drag(formList(), const Offset(0, -3000));
        await tester.pumpAndSettle();

        final screenHeight =
            tester.view.physicalSize.height / tester.view.devicePixelRatio;
        final buttonRect = tester.getRect(orderButton());

        // El botón debe quedar COMPLETAMENTE por encima de la barra de
        // navegación, nunca parcialmente tapado.
        expect(
          buttonRect.bottom,
          lessThanOrEqualTo(screenHeight - 48),
          reason: 'El botón se sale de la zona segura inferior.',
        );
      },
    );

    testWidgets(
      'dentro del bottom sheet el teclado se descuenta UNA sola vez',
      (tester) async {
        // Reproduce la estructura real de PosScreen: un `Padding` externo con
        // `viewInsets.bottom` envolviendo al `CheckoutScreen`.
        //
        // Con `resizeToAvoidBottomInset: true` en el Scaffold, el inset se
        // contaba dos veces y quedaba un área en blanco tapando el botón.
        await showInBottomSheet(tester, keyboardHeight: kKeyboardHeight);
        addTearDown(tester.view.reset);

        // El botón está al final: hay que construirlo con un scroll.
        await tester.drag(formList(), const Offset(0, -3000));
        await tester.pumpAndSettle();

        // El botón debe existir y ser alcanzable.
        expect(orderButton(), findsOneWidget);

        // El `ListView` debe conservar altura visible positiva: si el teclado
        // se descontara dos veces, el espacio del formulario quedaría a cero o
        // casi a cero y el botón quedaría fuera de la zona visible.
        expect(
          tester.getSize(formList()).height,
          greaterThan(0),
          reason: 'El formulario quedó sin espacio visible.',
        );
      },
    );

    testWidgets(
      'no queda un hueco en blanco del tamaño del teclado al final del scroll',
      (tester) async {
        tester.view.viewInsets = const FakeViewPadding(bottom: kKeyboardHeight);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        // Desplazamos hasta el final del contenido.
        await tester.drag(formList(), const Offset(0, -3000));
        await tester.pumpAndSettle();

        final listRect = tester.getRect(formList());
        final buttonRect = tester.getRect(
          find.widgetWithText(ElevatedButton, 'PROCESAR ORDEN'),
        );

        // El último botón debe quedar pegado al final visible del listado,
        // separado únicamente por su padding (24) más el espaciado final (8).
        // Antes del fix esta distancia era de 32 + altura del teclado: el área
        // en blanco del tamaño del teclado que tapaba los campos.
        final trailingGap = listRect.bottom - buttonRect.bottom;

        expect(trailingGap, moreOrLessEquals(32, epsilon: 1));
        expect(trailingGap, lessThan(kKeyboardHeight));
      },
    );
  });

  group('Campo Desc. Volumen', () {
    Finder volumeField() =>
        find.widgetWithText(TextFormField, 'Desc. Volumen (\$)');

    testWidgets('arranca vacío: "0.0" es solo un hint, no texto real',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      final editable = tester.widget<EditableText>(
        find.descendant(of: volumeField(), matching: find.byType(EditableText)),
      );

      // Sin texto real: el usuario no tiene que borrar "0.0" para escribir.
      expect(editable.controller.text, isEmpty);

      // El ejemplo "0.0" sí se muestra, pero como hint (placeholder).
      expect(find.text('0.0'), findsOneWidget);
    });

    testWidgets('el total arranca sin descuento y baja al escribir un valor',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // El bloque del total está al final del formulario: hay que construirlo.
      await tester.drag(formList(), const Offset(0, -3000));
      await tester.pumpAndSettle();

      // Subtotal 50, sin descuento -> el total a pagar es 50.00
      // (el texto "$50.00" aparece 2 veces: en Subtotal y en TOTAL A PAGAR).
      expect(find.text(r'$50.00'), findsNWidgets(2));
      expect(find.text(r'$44.50'), findsNothing);

      await tester.enterText(volumeField(), '5.50');
      await tester.pumpAndSettle();

      // 50.00 - 5.50 = 44.50
      expect(find.text(r'$44.50'), findsOneWidget);
    });

    testWidgets('al enviar la orden con el campo vacío se manda 0.0',
        (tester) async {
      CreateOrderIn? sent;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: CheckoutScreen(
              cartItems: [OrderItemIn(variationId: 1, quantity: 1)],
              subtotal: 50,
              currentRate: null,
              onSubmitOrder: (p) async => sent = p,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // "cliente" es obligatorio: lo rellenamos para que el form valide.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre del cliente *'),
        'Ana',
      );
      await tester.pumpAndSettle();

      await tester.drag(formList(), const Offset(0, -3000));
      await tester.pumpAndSettle();
      await tester.tap(orderButton());
      await tester.pumpAndSettle();

      // Campo vacío no debe romper el envío: el descuento se envía como 0.0.
      expect(sent, isNotNull);
      expect(sent!.discountVolumen, 0.0);
    });
    testWidgets('los botones rápidos 10/20/30% fijan el descuento del subtotal',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      EditableText editable() => tester.widget<EditableText>(
            find.descendant(
                of: volumeField(), matching: find.byType(EditableText)),
          );

      // Subtotal 50: 10% -> 5.00
      await tester.tap(find.text('10%'));
      await tester.pumpAndSettle();
      expect(editable().controller.text, '5.00');

      // 20% -> 10.00 (reemplaza el valor anterior, no lo suma)
      await tester.tap(find.text('20%'));
      await tester.pumpAndSettle();
      expect(editable().controller.text, '10.00');

      // 30% -> 15.00
      await tester.tap(find.text('30%'));
      await tester.pumpAndSettle();
      expect(editable().controller.text, '15.00');

      // El total refleja el descuento: 50 - 15 = 35
      await tester.drag(formList(), const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(find.text(r'$35.00'), findsOneWidget);
    });

    testWidgets('los botones rápidos muestran el monto que van a aplicar',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Subtotal 50 -> 5.00 / 10.00 / 15.00
      expect(find.text(r'$5.00'), findsOneWidget);
      expect(find.text(r'$10.00'), findsOneWidget);
      expect(find.text(r'$15.00'), findsOneWidget);
    });

    testWidgets('escribir a mano deja de resaltar ningún botón rápido',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Color de fondo del botón: null cuando no está seleccionado.
      Color? buttonColor(String percent) {
        final button = tester.widget<OutlinedButton>(find.ancestor(
          of: find.text(percent),
          matching: find.byType(OutlinedButton),
        ));
        return button.style?.backgroundColor?.resolve({});
      }

      await tester.tap(find.text('20%'));
      await tester.pumpAndSettle();

      // Al pulsar 20% el botón queda resaltado.
      expect(buttonColor('20%'), isNotNull);
      expect(buttonColor('10%'), isNull);

      // Al escribir un valor manual ya no debe coincidir con ningún %.
      await tester.enterText(volumeField(), '7');
      await tester.pumpAndSettle();

      expect(buttonColor('20%'), isNull);
      expect(buttonColor('10%'), isNull);
    });

    testWidgets('el botón Limpiar borra el descuento y restablece el total',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      EditableText editable() => tester.widget<EditableText>(
            find.descendant(
                of: volumeField(), matching: find.byType(EditableText)),
          );

      // Aplicamos un 30% (subtotal 50 -> 15.00)
      await tester.tap(find.text('30%'));
      await tester.pumpAndSettle();
      expect(editable().controller.text, '15.00');

      // "Limpiar" vacía el campo...
      await tester.tap(find.text('Limpiar'));
      await tester.pumpAndSettle();
      expect(editable().controller.text, isEmpty);

      // ...y el total vuelve al subtotal completo.
      await tester.drag(formList(), const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(find.text(r'$35.00'), findsNothing);
      expect(find.text(r'$50.00'), findsNWidgets(2));
    });

    testWidgets('Limpiar está deshabilitado cuando no hay descuento',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      bool isEnabled() => tester
          .widget<OutlinedButton>(
            find.ancestor(
              of: find.text('Limpiar'),
              matching: find.byType(OutlinedButton),
            ),
          )
          .onPressed !=
          null;

      // Sin descuento -> botón deshabilitado.
      expect(isEnabled(), isFalse);

      // Con descuento -> botón habilitado.
      await tester.tap(find.text('10%'));
      await tester.pumpAndSettle();
      expect(isEnabled(), isTrue);

      // Tras limpiar, vuelve a deshabilitarse.
      await tester.tap(find.text('Limpiar'));
      await tester.pumpAndSettle();
      expect(isEnabled(), isFalse);
    });
  });

  authErrorGroup();
}

Future<void> _noopSubmit(CreateOrderIn payload) async {}

/// Construye un [AuthRepository] cuyo POST a /token/pair responde [statusCode]
/// con [body], o falla con un error de red si [networkError] es true.
AuthRepository buildAuthRepository({
  int statusCode = 401,
  Object? body = const {'detail': 'No active account found'},
  bool networkError = false,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));

  if (networkError) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
              error: 'fallo de red',
            ),
          );
        },
      ),
    );
  } else {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final response = Response(
            requestOptions: options,
            statusCode: statusCode,
            data: body,
          );

          // Por defecto Dio resuelve los 4xx/5xx sin lanzar. Se rechaza a mano
          // para reproducir la excepción real que llega al repositorio.
          if (statusCode >= 400) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: response,
                type: DioExceptionType.badResponse,
              ),
            );
          } else {
            handler.resolve(response);
          }
        },
      ),
    );
  }

  return AuthRepository(dio);
}

/// Ejecuta los casos de mensajes de error del login.
void authErrorGroup() {
  group('Botón de actualizar del POS', () {
    Finder refreshButton() => find.byTooltip('Actualizar catálogo');

    late int calls;

    setUp(() => calls = 0);

    Future<void> pumpPos(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            catalogRepositoryProvider.overrideWithValue(
              _FakeCatalogRepository(() => calls++),
            ),
            currentExchangeRateProvider.overrideWith(
              (ref) async => ExchangeRate(
                currency: 'USD_VES',
                rate: 36.5,
                updatedAt: DateTime(2026),
              ),
            ),
            cartProvider.overrideWith(() => _SeededCartNotifier()),
          ],
          child: const MaterialApp(home: PosScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('el botón existe en la barra superior', (tester) async {
      await pumpPos(tester);

      expect(refreshButton(), findsOneWidget);
    });

    testWidgets('al pulsarlo vuelve a pedir los productos', (tester) async {
      await pumpPos(tester);

      final callsBefore = calls;
      expect(callsBefore, greaterThan(0));

      await tester.tap(refreshButton());
      await tester.pumpAndSettle();

      // Los productos se vuelven a solicitar al backend.
      expect(calls, greaterThan(callsBefore));
    });

    testWidgets('el refresh NO vacía el carrito en curso', (tester) async {
      await pumpPos(tester);

      // El carrito tiene un producto sembrado.
      expect(find.text('Producto de prueba'), findsOneWidget);

      await tester.tap(refreshButton());
      await tester.pumpAndSettle();

      // La orden en curso debe sobrevivir al refresco del catálogo.
      expect(find.text('Producto de prueba'), findsOneWidget);
    });

    testWidgets('confirma con un SnackBar que el catálogo se actualizó',
        (tester) async {
      await pumpPos(tester);

      await tester.tap(refreshButton());
      await tester.pumpAndSettle();

      expect(find.text('Catálogo actualizado'), findsOneWidget);
    });
  });

  group('CartPanel y la barra de navegación de Android', () {
    const navBar = 48.0;

    Finder checkoutButton() =>
        find.widgetWithText(ElevatedButton, 'PROCESAR COBRO');

    double screenHeight(WidgetTester tester) =>
        tester.view.physicalSize.height / tester.view.devicePixelRatio;

    /// Monta el CartPanel con un carrito con productos y [bottomInset] de
    /// sistema, replicando los dos contenedores reales de `PosScreen`.
    Future<void> pumpPanel(
      WidgetTester tester, {
      required bool inBottomSheet,
      double bottomInset = navBar,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cartProvider.overrideWith(() => _SeededCartNotifier()),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (hostContext) {
                return MediaQuery(
                  data: MediaQuery.of(hostContext).copyWith(
                    viewPadding: MediaQuery.of(hostContext)
                        .viewPadding
                        .copyWith(bottom: bottomInset),
                    padding: MediaQuery.of(hostContext)
                        .padding
                        .copyWith(bottom: bottomInset),
                  ),
                  child: Scaffold(
                    body: inBottomSheet
                        ? Center(
                            child: FractionallySizedBox(
                              heightFactor: 0.85,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: CartPanel(
                                  currentRate: 36.5,
                                  onCheckout: () {},
                                ),
                              ),
                            ),
                          )
                        : Row(
                            children: [
                              const Expanded(child: SizedBox.shrink()),
                              Container(
                                width: 380,
                                padding: const EdgeInsets.all(16),
                                child: CartPanel(
                                  currentRate: 36.5,
                                  onCheckout: () {},
                                ),
                              ),
                            ],
                          ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'en el panel lateral (tablet) el botón queda sobre la barra de navegación',
      (tester) async {
        await pumpPanel(tester, inBottomSheet: false);

        expect(
          tester.getRect(checkoutButton()).bottom,
          lessThanOrEqualTo(screenHeight(tester) - navBar),
          reason: 'El botón quedó tapado por la barra de navegación de Android.',
        );
      },
    );

    testWidgets(
      'dentro del bottom sheet el botón queda sobre la barra de navegación',
      (tester) async {
        await pumpPanel(tester, inBottomSheet: true);

        expect(
          tester.getRect(checkoutButton()).bottom,
          lessThanOrEqualTo(screenHeight(tester) - navBar),
          reason: 'El botón quedó tapado por la barra de navegación de Android.',
        );
      },
    );

    testWidgets('sin barra de navegación el botón llega al borde inferior',
        (tester) async {
      await pumpPanel(tester, inBottomSheet: true, bottomInset: 0);

      // Sin inset de sistema, el botón aprovecha hasta el borde.
      expect(
        tester.getRect(checkoutButton()).bottom,
        lessThanOrEqualTo(screenHeight(tester)),
      );
    });
  });

  group('AuthRepository mensajes de error', () {
    Future<String> loginError(AuthRepository repo) async {
      try {
        await repo.login('usuario', 'clave');
        return '';
      } catch (e) {
        return e.toString().replaceAll('Exception: ', '');
      }
    }

    test('401 muestra un mensaje amigable de usuario/contraseña', () async {
      final repo = buildAuthRepository(
        statusCode: 401,
        body: {'detail': 'No active account found with the given credentials'},
      );

      final message = await loginError(repo);

      expect(
        message,
        'No se encuentra dicha combinación de usuario y contraseña.',
      );
      // Nunca debe filtrarse el texto crudo del backend.
      expect(message, isNot(contains('No active account')));
    });

    test('400 (respuesta típica de djoser) también es amigable', () async {
      final repo = buildAuthRepository(
        statusCode: 400,
        body: {'detail': 'No active account found with the given credentials'},
      );

      expect(
        await loginError(repo),
        'No se encuentra dicha combinación de usuario y contraseña.',
      );
    });

    test('403 muestra el mismo mensaje amigable', () async {
      final repo = buildAuthRepository(statusCode: 403, body: {'detail': 'x'});

      expect(
        await loginError(repo),
        'No se encuentra dicha combinación de usuario y contraseña.',
      );
    });

    test('error de conexión no muestra el código crudo de Dio', () async {
      final repo = buildAuthRepository(networkError: true);

      final message = await loginError(repo);

      expect(
        message,
        'No se pudo conectar con el servidor. Revisa tu conexión a internet.',
      );
      expect(message, isNot(contains('DioException')));
      expect(message, isNot(contains('connectionError')));
    });

    test('422 de FastAPI usa el msg del primer error, no el mapa crudo',
        () async {
      final repo = buildAuthRepository(
        statusCode: 422,
        body: {
          'detail': [
            {'loc': ['body', 'username'], 'msg': 'Este campo es requerido.'},
          ],
        },
      );

      expect(await loginError(repo), 'Este campo es requerido.');
    });

    test('respuesta con body no textual cae en un mensaje genérico', () async {
      final repo = buildAuthRepository(
        statusCode: 500,
        body: {
          'error': 'algo raro',
        },
      );

      expect(
        await loginError(repo),
        'Ocurrió un error inesperado. Inténtalo de nuevo.',
      );
    });
  });
}
