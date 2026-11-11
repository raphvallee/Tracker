import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/services/session_summary.dart';

WorkoutSet _set(
  int exerciseId,
  double weight,
  double reps, {
  bool warmup = false,
  int order = 0,
}) => WorkoutSet(
  exerciseId: exerciseId,
  weight: weight,
  reps: reps,
  type: warmup ? SetType.warmup : SetType.working,
  order: order,
);

void main() {
  group('groupByExercise', () {
    test('keeps exercises in the order first logged, sets in logged order', () {
      final groups = groupByExercise([
        _set(2, 40, 10, warmup: true),
        _set(1, 60, 8),
        _set(2, 80, 8),
        _set(1, 62.5, 6),
        _set(3, 10, 15),
      ]);
      expect([for (final g in groups) g.exerciseId], [2, 1, 3]);
      expect([for (final s in groups[0].sets) s.weight], [40, 80]);
      expect([for (final s in groups[1].sets) s.weight], [60, 62.5]);
      expect(groups[0].workingCount, 1);
      expect(groups[0].warmupCount, 1);
    });

    test('is empty for no sets', () {
      expect(groupByExercise(const []), isEmpty);
    });
  });

  group('topSetOf', () {
    test('picks the heaviest working set, more reps among equals', () {
      final top = topSetOf([
        _set(1, 100, 3, warmup: true),
        _set(1, 80, 8),
        _set(1, 80, 9),
        _set(1, 75, 12),
      ]);
      expect(top?.weight, 80);
      expect(top?.reps, 9);
    });

    test('falls back to the heaviest warm-up when only warm-ups exist', () {
      final top = topSetOf([
        _set(1, 40, 10, warmup: true),
        _set(1, 60, 5, warmup: true),
      ]);
      expect(top?.weight, 60);
    });

    test('is null for no sets', () {
      expect(topSetOf(const []), isNull);
    });
  });

  test('working volume and set count leave warm-ups out', () {
    final sets = [
      _set(1, 60, 10, warmup: true),
      _set(1, 100, 5),
      _set(2, 20, 10),
    ];
    expect(workingVolumeOf(sets), 700);
    expect(workingSetCount(sets), 2);
    expect(workingVolumeOf(const []), 0);
  });

  group('exercisePreview', () {
    test('lists two exercises and counts the rest', () {
      expect(
        exercisePreview([
          'Bench press',
          'Overhead press',
          'Dips',
          'Fly',
          'Pushdown',
        ]),
        'Bench press, Overhead press and 3 more',
      );
      expect(
        exercisePreview(['Squat', 'Bench press', 'Row']),
        'Squat, Bench press and 1 more',
      );
    });

    test('lists one or two exercises as they are', () {
      expect(exercisePreview(['Squat']), 'Squat');
      expect(exercisePreview(['Squat', 'Bench press']), 'Squat, Bench press');
    });

    test('says when nothing was logged', () {
      expect(exercisePreview(const []), 'No sets logged');
    });
  });

  test('setCountsLabel names warm-ups only when there are', () {
    expect(setCountsLabel(4, 2), '4 sets, 2 warm-ups');
    expect(setCountsLabel(3, 0), '3 sets');
    expect(setCountsLabel(1, 1), '1 set, 1 warm-up');
    expect(setCountsLabel(0, 2), '2 warm-ups');
  });
}
