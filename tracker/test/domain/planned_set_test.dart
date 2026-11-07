import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/models/workout_split.dart';

void main() {
  group('PlannedSet', () {
    test('fixed set is detected by a null max', () {
      final set = PlannedSet(order: 0, minReps: 10);
      expect(set.isRange, isFalse);
      expect(set.repsLabel, '10');
    });

    test('range set renders its bounds', () {
      final set = PlannedSet(order: 1, minReps: 8, maxReps: 12);
      expect(set.isRange, isTrue);
      expect(set.repsLabel, '8-12');
    });
  });

  group('plannedSetsSummary', () {
    test('returns null for an empty list', () {
      expect(plannedSetsSummary(const []), isNull);
    });

    test('collapses identical targets into one labelled phrase', () {
      final sets = [
        PlannedSet(order: 0, minReps: 8, maxReps: 12),
        PlannedSet(order: 1, minReps: 8, maxReps: 12),
        PlannedSet(order: 2, minReps: 8, maxReps: 12),
      ];
      expect(plannedSetsSummary(sets), '3 sets × 8-12 reps');
    });

    test('uses singular set and rep for a single fixed set of one rep', () {
      final sets = [PlannedSet(order: 0, minReps: 1)];
      expect(plannedSetsSummary(sets), '1 set × 1 rep');
    });

    test('uses singular set for a single set', () {
      final sets = [PlannedSet(order: 0, minReps: 10)];
      expect(plannedSetsSummary(sets), '1 set × 10 reps');
    });

    test('keeps plural rep for identical fixed sets of one rep', () {
      final sets = [
        PlannedSet(order: 0, minReps: 1),
        PlannedSet(order: 1, minReps: 1),
      ];
      expect(plannedSetsSummary(sets), '2 sets × 1 rep');
    });

    test('lists every target in order when sets differ', () {
      final sets = [
        PlannedSet(order: 0, minReps: 10),
        PlannedSet(order: 1, minReps: 8, maxReps: 12),
        PlannedSet(order: 2, minReps: 8, maxReps: 12),
      ];
      expect(plannedSetsSummary(sets), '10, 8-12, 8-12 reps');
    });

    test('lists a two-set mixed plan without a set count', () {
      final sets = [
        PlannedSet(order: 0, minReps: 10),
        PlannedSet(order: 1, minReps: 8, maxReps: 12),
      ];
      expect(plannedSetsSummary(sets), '10, 8-12 reps');
    });
  });
}
