import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:naavis_pos/core/db/app_database.dart';
import 'package:naavis_pos/core/db/app_providers.dart';
import 'package:naavis_pos/features/checkout/data/models/create_order_dto.dart';
import 'package:naavis_pos/features/checkout/data/models/payments_config.dart';
import 'package:naavis_pos/features/checkout/presentation/checkout_screen.dart';

/// Config de comisión falsa (la misma del panel: 5.4% + $0.30).
class _FakePaymentsConfig extends PaymentsConfigNotifier {
  @override
  Future<PaymentsConfig> build() async => const PaymentsConfig(
        paypalCommissionPct: 5.4,
        paypalCommissionFixed: 0.30,
      );
}

void main() {
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // DB en memoria por test: evita los avisos de drift por abrir la real.
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  // ── DTO ────────────────────────────────────────────────────────────

  group('CreateOrderIn pagos', () {
    CreateOrderIn buildDto({List<PaymentSplit> pagos = const []}) =>
        CreateOrderIn(
          customerName: 'Ana',
          deliveryType: 'PICKUP',
          paymentMethod: 'PAGOMOVIL',
          items: [OrderItemIn(variationId: 1, quantity: 2)],
          pagos: pagos,
        );

    test('sin mixto no envía la clave pagos (payload de siempre)', () {
      final json = buildDto().toJson();
      expect(json.containsKey('pagos'), isFalse);
      expect(json['payment_method'], 'PAGOMOVIL');
    });

    test('con mixto serializa cada parte como metodo/monto', () {
      final json = buildDto(pagos: [
        PaymentSplit(method: 'EFECTIVO_USD', amount: 5.0),
        PaymentSplit(method: 'PAGOMOVIL', amount: 15.0),
      ]).toJson();

      expect(json['payment_method'], 'PAGOMOVIL'); // lo decide el caller
      expect(json['pagos'], [
        {'metodo': 'EFECTIVO_USD', 'monto': 5.0},
        {'metodo': 'PAGOMOVIL', 'monto': 15.0},
      ]);
    });
  });

  // ── Checkout ───────────────────────────────────────────────────────

  /// Todos los campos de monto del mixto (orden = orden de las filas).
  Finder mixedAmounts() => find.byWidgetPredicate(
        (w) =>
            w is TextFormField &&
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('mixed_amount_'),
      );

  Finder mixedAmount(int index) => mixedAmounts().at(index);

  Future<void> selectPaymentOption(WidgetTester tester, String label) async {
    // 0 = entrega, 1 = método de pago.
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> pumpCheckout(
    WidgetTester tester, {
    required void Function(CreateOrderIn payload) onSubmit,
    bool overrideConfig = false,
  }) async {
    // Pantalla alta: el formulario completo cabe sin scrollear.
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          if (overrideConfig)
            paymentsConfigProvider.overrideWith(() => _FakePaymentsConfig()),
        ],
        child: MaterialApp(
          home: CheckoutScreen(
            cartItems: [OrderItemIn(variationId: 1, quantity: 2)],
            subtotal: 20.0,
            onSubmitOrder: (payload) async => onSubmit(payload),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillName(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).first, 'Ana');
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester) async {
    final boton = find.text('PROCESAR ORDEN');
    await tester.ensureVisible(boton);
    await tester.pumpAndSettle();
    await tester.tap(boton);
    await tester.pumpAndSettle();
  }

  testWidgets('pago mixto: arma el reparto y elige el método de mayor monto',
      (tester) async {
    CreateOrderIn? captured;
    await pumpCheckout(tester, onSubmit: (p) => captured = p);

    await fillName(tester);
    await selectPaymentOption(tester, 'Pago mixto (varios métodos)');
    await tester.enterText(mixedAmount(0), '5');
    await tester.pump();
    await tester.enterText(mixedAmount(1), '15');
    await tester.pump();

    // Resumen del panel: asignado vs total.
    expect(find.text('Asignado \$20.00 de \$20.00'), findsOneWidget);

    await submit(tester);

    expect(captured, isNotNull);
    expect(captured!.paymentMethod, 'PAGOMOVIL'); // mayor monto (15)
    expect(captured!.pagos, hasLength(2));
    expect(captured!.pagos.first.method, 'EFECTIVO_USD');
    expect(captured!.pagos.first.amount, 5.0);
    expect(captured!.pagos.last.method, 'PAGOMOVIL');
    expect(captured!.pagos.last.amount, 15.0);
  });

  testWidgets('pago mixto que no cubre el total no se envía y avisa',
      (tester) async {
    CreateOrderIn? captured;
    await pumpCheckout(tester, onSubmit: (p) => captured = p);

    await fillName(tester);
    await selectPaymentOption(tester, 'Pago mixto (varios métodos)');
    await tester.enterText(mixedAmount(0), '5');
    await tester.pump();
    await tester.enterText(mixedAmount(1), '10');
    await tester.pump();

    expect(find.text('Asignado \$15.00 de \$20.00'), findsOneWidget);

    await submit(tester);

    expect(captured, isNull); // nunca llegó a onSubmitOrder
    expect(
      find.textContaining('El pago mixto suma \$15.00'),
      findsOneWidget,
    );
  });

  testWidgets('agrega y quita filas del pago mixto', (tester) async {
    await pumpCheckout(tester, onSubmit: (_) {});

    await fillName(tester);
    await selectPaymentOption(tester, 'Pago mixto (varios métodos)');
    expect(mixedAmounts(), findsNWidgets(2));

    await tester.tap(find.text('Agregar método'));
    await tester.pump();
    expect(mixedAmounts(), findsNWidgets(3));

    // Con tres filas la última se puede quitar; nunca bajan de dos.
    await tester.tap(find.byTooltip('Quitar este método').last);
    await tester.pump();
    expect(mixedAmounts(), findsNWidgets(2));
  });

  testWidgets('PayPal: muestra lo que envía el cliente con la comisión',
      (tester) async {
    await pumpCheckout(tester, onSubmit: (_) {}, overrideConfig: true);

    await fillName(tester);
    await selectPaymentOption(tester, 'PayPal');

    // (20 + 0.30) / (1 − 0.054) = 21.46
    expect(
      find.text('El cliente envía por PayPal \$21.46'),
      findsOneWidget,
    );
    expect(
      find.text('incluye la comisión 5.4% + \$0.30'),
      findsOneWidget,
    );
  });

  testWidgets('sin nombre el POS envía Cliente Anonimo', (tester) async {
    CreateOrderIn? captured;
    await pumpCheckout(tester, onSubmit: (p) => captured = p);

    // Ni se toca el campo: el form ya no exige nombre.
    await submit(tester);

    expect(captured, isNotNull);
    expect(captured!.customerName, 'Cliente Anonimo');
  });
}

