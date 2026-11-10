import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/domain/services/set_prefill.dart';

void main() {
  final previous = PreviousPerformance(
    date: DateTime(2026, 3, 1),
    sets: [
      WorkoutSet(exerciseId: 1, weight: 14, reps: 12, type: SetType.warmup),
      WorkoutSet(exerciseId: 1, weight: 30, reps: 10, order: 1),
      WorkoutSet(exerciseId: 1, weight: 30, reps: 9, order: 2),
    ],
  );
  final planned = [
    PlannedSet(order: 0, minReps: 8, maxReps: 12),
    PlannedSet(order: 1, minReps: 8, maxReps: 12),
    PlannedSet(order: 2, minReps: 6),
    PlannedSet(order: 3, minReps: 6),
  ];

  test('a row takes last session set at its position, type included', () {
    // Last session's opening warm-up comes first, ahead of the plan.
    final lead = leadingWarmupRows(planned, previous);
    expect(lead, 1);
    final warmup = ghostForRow(
      index: 0,
      previous: previous,
      planned: planned,
      lead: lead,
    );
    expect((warmup.weight, warmup.reps, warmup.warmup), (14, 12, true));
    final second = ghostForRow(
      index: 2,
      previous: previous,
      planned: planned,
      lead: lead,
    );
    expect((second.weight, second.reps, second.warmup), (30, 9, false));
  });

  test('planned warm-ups type their rows and take no extra ones', () {
    final withWarmup = [
      PlannedSet(minReps: 10, isWarmup: true),
      PlannedSet(order: 1, minReps: 8, maxReps: 12),
    ];
    final working = PreviousPerformance(
      date: DateTime(2026, 3, 1),
      sets: [
        WorkoutSet(weight: 60, reps: 8),
        WorkoutSet(weight: 20, reps: 10, type: SetType.warmup, order: 1),
      ],
    );
    expect(leadingWarmupRows(withWarmup, previous), 0);
    expect(leadingWarmupRows(const [], previous), 0, reason: 'no plan');
    expect(leadingWarmupRows(planned, null), 0);
    final first = ghostForRow(index: 0, previous: working, planned: withWarmup);
    expect((first.weight, first.warmup), (60, true), reason: 'plan wins');
    final next = ghostForRow(index: 1, previous: working, planned: withWarmup);
    expect(next.warmup, isFalse);
    final blank = ghostForRow(index: 0, planned: withWarmup);
    expect((blank.reps, blank.warmup), (10, true));
    expect(plannedForRow(0, withWarmup, lead: 1), isNull);
    expect(plannedForRow(1, withWarmup, lead: 1), withWarmup.first);
  });

  test('past last session, the plan gives the reps and the row above the '
      'weight', () {
    final ghost = ghostForRow(
      index: 3,
      previous: previous,
      planned: planned,
      lead: 1,
      previousWeight: 32.5,
      previousReps: 9,
    );
    expect((ghost.weight, ghost.reps, ghost.warmup), (32.5, 6, false));
  });

  test('a range target prefills its lower end', () {
    final ghost = ghostForRow(index: 1, planned: planned);
    expect(ghost.reps, 8);
    expect(ghost.weight, isNull);
  });

  test('without a plan or history the row above is copied', () {
    final ghost = ghostForRow(index: 4, previousWeight: 50, previousReps: 5);
    expect((ghost.weight, ghost.reps), (50, 5));
    expect(ghostForRow(index: 0).weight, isNull);
  });

  test('topSet is the heaviest working set, more reps among equals', () {
    expect(previous.topSet!.reps, 10, reason: '30 x 10 over 30 x 9');
    final heavier = PreviousPerformance(
      date: DateTime(2026, 3, 1),
      sets: [
        WorkoutSet(exerciseId: 1, weight: 60, reps: 5, type: SetType.warmup),
        WorkoutSet(exerciseId: 1, weight: 40, reps: 12, order: 1),
        WorkoutSet(exerciseId: 1, weight: 50, reps: 6, order: 2),
      ],
    );
    expect(heavier.topSet!.weight, 50, reason: 'warm-ups do not count');
    final warmupsOnly = PreviousPerformance(
      date: DateTime(2026, 3, 1),
      sets: [WorkoutSet(exerciseId: 1, weight: 20, type: SetType.warmup)],
    );
    expect(warmupsOnly.topSet, isNull);
  });

  test('leadingWarmups counts only the warm-ups before the first working '
      'set', () {
    expect(previous.leadingWarmups, 1);
    final mixed = PreviousPerformance(
      date: DateTime(2026, 3, 1),
      sets: [
        WorkoutSet(weight: 60, reps: 5),
        WorkoutSet(weight: 40, reps: 10, type: SetType.warmup),
      ],
    );
    expect(mixed.leadingWarmups, 0);
  });
}
