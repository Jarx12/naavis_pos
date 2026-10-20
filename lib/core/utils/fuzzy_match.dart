/// Búsqueda difusa (tolerante a typos) para el POS.
///
/// La coincidencia exacta por subcadena tiene prioridad siempre; la
/// tolerancia a errores de tipeo se agrega como un presupuesto de
/// ediciones que crece con el largo de la consulta (1 edición para
/// consultas de 3-6 chars y 2 para las de 7 o más, lo que equivale a
/// exigir una similitud normalizada de ~0.7-0.8 en los matches difusos).
/// Así un "zapatoss" encuentra "zapatos", pero una consulta corta ("ab")
/// o un código numérico ("54321") no traen media tienda por ruido.
library;

import 'dart:math' as math;

/// Tope de ediciones toleradas, sin importar cuán larga sea la consulta.
/// Evita que consultas largas con errores gruesos peguen con todo.
const int _kMaxTypoDistanceCap = 2;

/// Máximo número de ediciones (typos) que se toleran para una consulta
/// de cierto largo.
///
/// - Menos de 3 caracteres: 0 (solo subcadena exacta; nada de ruido).
/// - 3 a 6 caracteres: 1 edición.
/// - 7 o más: 2 ediciones (tope).
///
/// Las consultas puramente numéricas se tratan como códigos/barcodes y
/// no toleran ningún error.
int maxTypoDistance(String query) {
  final q = _normalize(query);
  if (int.tryParse(q) != null) return 0;
  if (q.length < 3) return 0;
  if (q.length <= 6) return 1;
  return _kMaxTypoDistanceCap;
}

/// Similitud normalizada entre dos textos en el rango [0, 1], donde 1 es
/// idéntico. Se basa en la distancia de Damerau-Levenshtein (OSA), que
/// cuenta también las transposiciones de dos caracteres vecinos como una
/// sola edición.
double fuzzySimilarity(String a, String b) {
  final na = _normalize(a);
  final nb = _normalize(b);
  final maxLen = math.max(na.length, nb.length);
  if (maxLen == 0) return 1.0;
  final distance = _editDistance(na, nb, maxLen);
  return 1 - (distance / maxLen);
}

/// true si [query] pega contra [text] tolerando pequeños typos.
///
/// Coincidencia exacta (case-insensitive) por subcadena primero; si no
/// pega, se toleran las ediciones indicadas por [maxTypoDistance]. Una
/// consulta de varias palabras debe pegar palabra por palabra contra el
/// texto (por prefijo exacto o con sus typos).
bool fuzzyMatch(String query, String text) {
  final q = _normalize(query);
  final t = _normalize(text);
  if (q.isEmpty) return true;
  if (t.isEmpty) return false;

  // Camino rápido: subcadena exacta. Cubre también los prefijos a medias
  // tipear y cualquier búsqueda sin errores.
  if (t.contains(q)) return true;

  final allowed = maxTypoDistance(q);
  if (allowed == 0) return false;

  final textWords = _splitWords(t);
  final queryWords = _splitWords(q);
  if (queryWords.length > 1) {
    // Consulta multi-palabra: cada palabra debe pegar en alguna palabra
    // del texto (exacta por prefijo o con sus typos individuales).
    return queryWords.every(
      (queryWord) => _matchesAnyWord(queryWord, textWords, allowed),
    );
  }

  // Palabra única: contra cada palabra del texto y contra el texto
  // completo (cubre nombres concatenados tipo "cocacola" vs "coca cola").
  return _matchesAnyWord(q, textWords, allowed) ||
      _editDistance(q, t, allowed) <= allowed;
}

/// true si alguna palabra de [words] empieza con [word] o está a lo sumo
/// [allowed] ediciones de distancia.
bool _matchesAnyWord(String word, List<String> words, int allowed) {
  for (final candidate in words) {
    if (candidate.startsWith(word)) return true;
    if (_editDistance(word, candidate, allowed) <= allowed) return true;
  }
  return false;
}

String _normalize(String value) => value.toLowerCase().trim();

List<String> _splitWords(String value) =>
    value.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

/// Distancia de Damerau-Levenshtein (optimal string alignment) entre [a]
/// y [b]. Si la distancia supera [cap] se corta antes (devuelve
/// cap + 1); sirve como cota para no calcular matrices completas.
int _editDistance(String a, String b, int cap) {
  if ((a.length - b.length).abs() > cap) return cap + 1;

  final n = b.length;
  var prev2 = List<int>.filled(n + 1, 0); // fila i-2
  var prev1 = List<int>.filled(n + 1, 0); // fila i-1
  for (var j = 0; j <= n; j++) {
    prev1[j] = j;
  }

  for (var i = 1; i <= a.length; i++) {
    final curr = List<int>.filled(n + 1, i);
    curr[0] = i;
    var rowMin = i;
    for (var j = 1; j <= n; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      var v = prev1[j - 1] + cost; // sustitución
      final insertion = curr[j - 1] + 1; // inserción
      if (insertion < v) v = insertion;
      final deletion = prev1[j] + 1; // borrado
      if (deletion < v) v = deletion;
      // Transposición de dos caracteres vecinos (ej. "teh" → "the").
      if (i > 1 &&
          j > 1 &&
          a[i - 1] == b[j - 2] &&
          a[i - 2] == b[j - 1]) {
        final transposition = prev2[j - 2] + 1;
        if (transposition < v) v = transposition;
      }
      curr[j] = v;
      if (v < rowMin) rowMin = v;
    }
    // El mínimo por fila nunca decrece: si ya superó la cota, cortar.
    if (rowMin > cap) return cap + 1;
    prev2 = prev1;
    prev1 = curr;
  }
  return prev1[n];
}
