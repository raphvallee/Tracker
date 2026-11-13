import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/services/fuzzy_search.dart';

void main() {
  group('editDistance', () {
    test('counts adds, removals, changes and swaps', () {
      expect(editDistance('squat', 'squat'), 0);
      expect(editDistance('bech', 'bench'), 1);
      expect(editDistance('sqaut', 'squat'), 1);
      expect(editDistance('pres', 'prez'), 1);
      expect(editDistance('deadlift', 'dedlfit'), 2);
    });

    test('stops once past the cap', () {
      expect(editDistance('row', 'deadlift', 1), 2);
    });
  });

  group('fuzzyWordMatches', () {
    test('finds the words a typed word starts', () {
      expect(fuzzyWordMatches('ben', 'bench'), isTrue);
      expect(fuzzyWordMatches('pres', 'press'), isTrue);
    });

    test('forgives a missing, extra, wrong or swapped letter', () {
      expect(fuzzyWordMatches('bech', 'bench'), isTrue);
      expect(fuzzyWordMatches('benchh', 'bench'), isTrue);
      expect(fuzzyWordMatches('bemch', 'bench'), isTrue);
      expect(fuzzyWordMatches('sqaut', 'squat'), isTrue);
      expect(fuzzyWordMatches('deadlfit', 'deadlift'), isTrue);
    });

    test('a typo still finds a word being typed', () {
      // Partly typed, with a letter missing.
      expect(fuzzyWordMatches('inclin', 'incline'), isTrue);
      expect(fuzzyWordMatches('incln', 'incline'), isTrue);
    });

    test('short words must be typed right', () {
      expect(fuzzyWordMatches('row', 'row'), isTrue);
      expect(fuzzyWordMatches('bow', 'row'), isFalse);
      expect(fuzzyWordMatches('pul', 'push'), isFalse);
    });

    test('words far apart do not match', () {
      expect(fuzzyWordMatches('squat', 'deadlift'), isFalse);
      expect(fuzzyWordMatches('push', 'pull'), isFalse);
      expect(fuzzyWordMatches('legs', 'lat'), isFalse);
    });
  });

  group('FuzzyQuery', () {
    test('every typed word must find a word', () {
      final query = FuzzyQuery('bech pres');
      expect(query.findsAll(searchWords('Bench Press')), isTrue);
      expect(query.findsAll(searchWords('Incline Bench Press')), isTrue);
      expect(query.findsAll(searchWords('Bench Dips')), isFalse);
    });

    test('ignores case and punctuation', () {
      expect(searchWords("Pull-up, Farmer's walk"), [
        'pull',
        'up',
        'farmer',
        's',
        'walk',
      ]);
      expect(FuzzyQuery('  ').isEmpty, isTrue);
    });
  });
}
