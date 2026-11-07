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

  group('repsUnit', () {
    test('is singular only for a fixed target of one rep', () {
      expect(PlannedSet(minReps: 1).repsUnit, 'rep');
      expect(PlannedSet(minReps: 10).repsUnit, 'reps');
      expect(PlannedSet(minReps: 1, maxReps: 3).repsUnit, 'reps');
    });
  });
}
