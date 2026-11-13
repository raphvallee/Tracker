/// Search that forgives typos: a word typed with a letter missing, extra,
/// wrong or two letters swapped still finds what it meant, and a word still
/// being typed finds the words it starts.
library;

final _separators = RegExp(r'[^a-z0-9]+');

/// The words of [text] as search compares them: lower case, letters and
/// digits only.
List<String> searchWords(String text) => [
  for (final word in text.toLowerCase().split(_separators))
    if (word.isNotEmpty) word,
];

/// How many typos a typed word of [length] letters may hold: none up to
/// three letters ("row" must not find "bow"), one up to seven, then two.
int typosAllowed(int length) => length <= 3
    ? 0
    : length <= 7
    ? 1
    : 2;

/// Whether the typed word [typed] finds [word]: [word] starts with it, or
/// starts with something at most [typosAllowed] typos away from it.
bool fuzzyWordMatches(String typed, String word) {
  if (word.startsWith(typed)) return true;
  final allowed = typosAllowed(typed.length);
  if (allowed == 0 || typed.length > word.length + allowed) return false;
  // Compared with the start of the word as long as the typed word, give or
  // take a typo's worth of letters: "bech" is one typo from "bench".
  final shortest = typed.length - allowed < 1 ? 1 : typed.length - allowed;
  final longest = typed.length + allowed > word.length
      ? word.length
      : typed.length + allowed;
  for (var length = shortest; length <= longest; length++) {
    if (editDistance(typed, word.substring(0, length), allowed) <= allowed) {
      return true;
    }
  }
  return false;
}

/// Letters to add, remove, change or swap with a neighbour to turn [a] into
/// [b] (optimal string alignment), or [cap] + 1 once it is past [cap].
int editDistance(String a, String b, [int cap = 1 << 30]) {
  if ((a.length - b.length).abs() > cap) return cap + 1;
  var before = List<int>.filled(b.length + 1, 0);
  var previous = List<int>.generate(b.length + 1, (j) => j);
  var current = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    current[0] = i;
    var rowBest = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      var best = previous[j - 1] + cost;
      if (previous[j] + 1 < best) best = previous[j] + 1;
      if (current[j - 1] + 1 < best) best = current[j - 1] + 1;
      if (i > 1 &&
          j > 1 &&
          a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
          a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1) &&
          before[j - 2] + 1 < best) {
        best = before[j - 2] + 1;
      }
      current[j] = best;
      if (best < rowBest) rowBest = best;
    }
    if (rowBest > cap) return cap + 1;
    final spare = before;
    before = previous;
    previous = current;
    current = spare;
  }
  return previous[b.length];
}

/// A search typed in a field: each of its words must find a word of what it
/// searches. What a word finds is remembered, since the same names (an
/// exercise, a split) come up in workout after workout.
class FuzzyQuery {
  FuzzyQuery(String text) : words = searchWords(text);

  final List<String> words;
  final List<Map<String, bool>> _found = [];

  bool get isEmpty => words.isEmpty;

  /// Whether the typed word at [index] finds [word].
  bool wordFinds(int index, String word) {
    while (_found.length <= index) {
      _found.add(<String, bool>{});
    }
    return _found[index][word] ??= fuzzyWordMatches(words[index], word);
  }

  /// Whether some typed word finds one of [targetWords].
  bool findsAny(Iterable<String> targetWords) {
    for (var i = 0; i < words.length; i++) {
      for (final word in targetWords) {
        if (wordFinds(i, word)) return true;
      }
    }
    return false;
  }

  /// Whether every typed word finds one of [targetWords].
  bool findsAll(Iterable<String> targetWords) {
    for (var i = 0; i < words.length; i++) {
      var found = false;
      for (final word in targetWords) {
        if (wordFinds(i, word)) {
          found = true;
          break;
        }
      }
      if (!found) return false;
    }
    return true;
  }
}
