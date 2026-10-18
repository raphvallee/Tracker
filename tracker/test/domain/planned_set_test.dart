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

    test('collapses identical targets into one label', () {
      final sets = [
        PlannedSet(order: 0, minReps: 8, maxReps: 12),
        PlannedSet(order: 1, minReps: 8, maxReps: 12),
        PlannedSet(order: 2, minReps: 8, maxReps: 12),
      ];
      expect(plannedSetsSummary(sets), '3 × 8-12');
    });

    test('lists each distinct target when sets differ', () {
      final sets = [
        PlannedSet(order: 0, minReps: 10),
        PlannedSet(order: 1, minReps: 8, maxReps: 12),
      ];
      expect(plannedSetsSummary(sets), '2 × 10, 8-12');
    });
  });
}
