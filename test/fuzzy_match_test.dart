import 'package:flutter_test/flutter_test.dart';

import 'package:naavis_pos/core/utils/fuzzy_match.dart';

void main() {
  group('fuzzyMatch — coincidencias exactas', () {
    test('consulta vacía matchea cualquier texto', () {
      expect(fuzzyMatch('', 'Cualquier cosa'), isTrue);
      expect(fuzzyMatch('   ', 'Cualquier cosa'), isTrue);
    });

    test('subcadena exacta, sin importar mayúsculas', () {
      expect(fuzzyMatch('zap', 'Zapatos Deportivos'), isTrue);
      expect(fuzzyMatch('ZAPATOS', 'zapatos negros'), isTrue);
      expect(fuzzyMatch('coca', 'Coca Cola 2L'), isTrue);
    });

    test('texto vacío nunca matchea con consulta no vacía', () {
      expect(fuzzyMatch('coca', ''), isFalse);
    });
  });

  group('fuzzyMatch — typos tolerados', () {
    test('sustitución en palabra corta (4 chars, 1 edición)', () {
      expect(fuzzyMatch('coqa', 'Coca Cola'), isTrue);
    });

    test('sobrante al final ("zapatoss" → "zapatos negros")', () {
      expect(fuzzyMatch('zapatoss', 'Zapatos Negros'), isTrue);
    });

    test('faltante al final ("pantalon" → "pantalones")', () {
      // 2 ediciones con consulta de 8 chars: dentro del tope.
      expect(fuzzyMatch('pantalon', 'Pantalones'), isTrue);
    });

    test('transposición de letras ("zpaatos" → "zapatos")', () {
      // Damerau cuenta la transposición como 1 sola edición.
      expect(fuzzyMatch('zpaatos', 'Zapatos'), isTrue);
    });

    test('nombre concatenado ("cocacola" → "coca cola")', () {
      expect(fuzzyMatch('cocacola', 'Coca Cola'), isTrue);
    });

    test('consulta multi-palabra con typo + prefijo exacto', () {
      expect(fuzzyMatch('zapatoss gran', 'Zapatos Grandes'), isTrue);
      expect(fuzzyMatch('zapatoss gran', 'Zapatos Pequeños'), isFalse);
    });

    test('busca también en la variación con typo', () {
      final variation = 'Rojo Oscuro';
      expect(fuzzyMatch('rojjo', variation), isTrue);
    });
  });

  group('fuzzyMatch — ruido evitado', () {
    test('consultas de 1-2 chars solo exactas', () {
      expect(fuzzyMatch('ab', 'axb'), isFalse);
      expect(fuzzyMatch('za', 'zapatos'), isTrue); // prefijo exacto
    });

    test('códigos numéricos sin tolerancia a typos', () {
      expect(fuzzyMatch('54321', 'Código 54322'), isFalse);
      expect(fuzzyMatch('54321', 'Código 54321'), isTrue);
    });

    test('palabras distintas no pegan por distancia grande', () {
      expect(fuzzyMatch('perro', 'Pera'), isFalse); // 2 ediciones, 5 chars
      expect(fuzzyMatch('mesa', 'Muelle'), isFalse);
    });

    test('letras sueltas no pegan con palabras largas', () {
      expect(fuzzyMatch('sal', 'Shampoo'), isFalse);
    });
  });

  group('fuzzySimilarity', () {
    test('textos idénticos dan 1.0', () {
      expect(fuzzySimilarity('Zapatos', 'zapatos '), closeTo(1.0, 1e-9));
    });

    test('un typo en 8 chars da 0.875', () {
      expect(fuzzySimilarity('zapatoss', 'zapatos'), closeTo(0.875, 1e-9));
    });

    test('transposición cuenta 1 edición', () {
      expect(fuzzySimilarity('zpaatos', 'zapatos'), closeTo(6 / 7, 1e-9));
    });
  });

  group('maxTypoDistance', () {
    test('escalona por largo y bloquea numéricos', () {
      expect(maxTypoDistance('ab'), 0);
      expect(maxTypoDistance('abc'), 1);
      expect(maxTypoDistance('abcdef'), 1);
      expect(maxTypoDistance('abcdefg'), 2);
      expect(maxTypoDistance('54321'), 0);
    });
  });
}
