import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:naavis_pos/core/platform/app_update.dart';
import 'package:naavis_pos/features/auth/presentation/widgets/force_update_button.dart';

/// Estos tests corren en la VM de Dart, es decir en la variante *stub*:
/// [AppUpdate.isSupported] es false y el botón no debe renderizar nada.
void main() {
  group('AppUpdate (stub fuera del web)', () {
    test('isSupported es false fuera del web', () {
      expect(AppUpdate.isSupported, isFalse);
    });

    test('clearServiceWorkerCaches responde "unsupported"', () async {
      final outcome = await AppUpdate.clearServiceWorkerCaches();
      expect(outcome.ok, isFalse);
      expect(outcome.error, 'unsupported');
      expect(outcome.unregistered, 0);
      expect(outcome.deleted, 0);
    });

    test('reload() es un no-op seguro', () {
      expect(AppUpdate.reload, returnsNormally);
    });
  });

  group('ForceUpdateButton', () {
    testWidgets('no renderiza nada fuera del web', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ForceUpdateButton()),
        ),
      );

      // El widget colapsa a SizedBox.shrink(): ni botón, ni icono, ni texto.
      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('Forzar'), findsNothing);
      expect(find.byType(ForceUpdateButton), findsOneWidget);
    });

    testWidgets('no ocupa espacio ni interrumpe el flujo del login',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ForceUpdateButton()),
        ),
      );

      expect(tester.getSize(find.byType(ForceUpdateButton)), Size.zero);
    });
  });

  group('AppUpdateOutcome', () {
    test('el constructor por defecto reporta éxito sin cambios', () {
      const outcome = AppUpdateOutcome(ok: true);
      expect(outcome.ok, isTrue);
      expect(outcome.unregistered, 0);
      expect(outcome.deleted, 0);
      expect(outcome.error, isNull);
    });

    test('carry de los contadores de service workers y cachés', () {
      const outcome = AppUpdateOutcome(ok: true, unregistered: 2, deleted: 7);
      expect(outcome.unregistered, 2);
      expect(outcome.deleted, 7);
    });
  });

  // El JS no se puede ejecutar aquí (no hay motor ES moderno en el entorno de
  // test), pero sí se puede blindar el invariante que, si se rompe, hace que el
  // botón deje de funcionar de forma silenciosa: hay que DESREGISTRAR los
  // service workers ANTES de borrar el Cache Storage. Si se invirtiera el
  // orden, el worker seguiría controlando la página y podría repoblar la caché
  // justo después de borrarla, y la recarga volvería a servir el bundle viejo.
  group('web/app_update.js (invariante de orden)', () {
    late String source;

    setUpAll(() {
      source = File('web/app_update.js').readAsStringSync();
    });

    test('desregistra los service workers antes de tocar las cachés', () {
      final unregister = source.indexOf('getRegistrations()');
      final deleteCaches = source.indexOf('caches.delete');
      expect(unregister, isNot(-1), reason: 'debe pedir las registraciones');
      expect(deleteCaches, isNot(-1), reason: 'debe borrar las cachés');
      expect(
        unregister,
        lessThan(deleteCaches),
        reason: 'si se borra la caché antes de desregistrar, el service '
            'worker la repuebla y la actualización no surte efecto',
      );
    });

    test('borra TODAS las claves del Cache Storage', () {
      // Un leftover de cualquier clave del precache sigue sirviendo la versión
      // vieja, así que hay que iterar sobre todas, no solo una.
      expect(source, contains('caches.keys()'));
      expect(source, contains('keys.map'));
    });

    test('la recarga final lleva un parámetro anti-caché', () {
      // Sin esto, el propio index.html puede seguir saliendo del HTTP cache.
      expect(source, contains('searchParams.set'));
      expect(source, contains('location.replace'));
    });

    test('expone los tres globals que consume el binding de Dart', () {
      expect(source, contains('window.naavisIsWebUpdateSupported'));
      expect(source, contains('window.naavisClearServiceWorkerCaches'));
      expect(source, contains('window.naavisHardReload'));
    });
  });
}

