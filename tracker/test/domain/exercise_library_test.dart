import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/muscle.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/domain/services/exercise_library.dart';

Exercise _exercise(
  int id,
  String title,
  List<Muscle> muscles, {
  List<Equipment> equipment = const [Equipment.barbell],
  MovementPattern movement = MovementPattern.unspecified,
}) => Exercise(
  title: title,
  primaryMuscle: muscles,
  equipment: equipment,
  movementPattern: movement,
)..id = id;

WorkoutSession _session(
  DateTime start,
  List<WorkoutSet> sets, {
  int? splitId,
  int? dayIndex,
}) => WorkoutSession(
  startTime: start,
  sets: sets,
  splitId: splitId,
  splitDayIndex: dayIndex,
);

WorkoutSet _set(
  int exerciseId,
  double weight,
  double reps, {
  bool warmup = false,
}) => WorkoutSet(
  exerciseId: exerciseId,
  weight: weight,
  reps: reps,
  type: warmup ? SetType.warmup : SetType.working,
);

void main() {
  final now = DateTime(2026, 11, 14, 12);
  final bench = _exercise(1, 'Bench Press', [
    Muscle.chest,
  ], movement: MovementPattern.push);
  final row = _exercise(2, 'Barbell Row', [
    Muscle.lats,
    Muscle.traps,
  ], movement: MovementPattern.pull);
  final pullUp = _exercise(
    3,
    'Pull Up',
    [Muscle.lats],
    equipment: [Equipment.bodyweight],
    movement: MovementPattern.pull,
  );
  final deadlift = _exercise(4, 'Deadlift', [
    Muscle.lowerBack,
    Muscle.hamstrings,
  ], movement: MovementPattern.pull);
  final crunch = _exercise(
    5,
    'cable crunch',
    [Muscle.abdominals, Muscle.obliques],
    equipment: [Equipment.cable],
    movement: MovementPattern.core,
  );

  WorkoutSplit split(int id, String title, Map<String, List<int>> days) =>
      WorkoutSplit(
        title: title,
        splitDays: [
          for (final MapEntry(key: day, value: ids) in days.entries)
            WorkoutSplitDay(
              title: day,
              exercises: [for (final id in ids) ExerciseItem(exerciseId: id)],
            ),
        ],
      )..id = id;

  // 99 was deleted from the library; Pull plans the row twice.
  final ppl = split(10, 'Push Pull Legs', {
    'Push': [1],
    'Pull': [2, 2],
    '  ': [4, 99],
  });
  final upperLower = split(11, 'Upper Lower', {
    'Upper': [1, 2],
    'Lower': [4],
  });

  ExerciseLibrary library({
    List<WorkoutSplit>? splits,
    int? currentSplitId = 10,
  }) => ExerciseLibrary.read(
    exercises: [pullUp, deadlift, bench, crunch, row],
    sessions: [
      _session(now.subtract(const Duration(days: 40)), [
        _set(4, 180, 2),
        _set(1, 90, 5),
      ]),
      _session(
        now.subtract(const Duration(days: 1)),
        [
          _set(1, 60, 10, warmup: true),
          _set(1, 100, 5),
          _set(1, 100, 6),
          _set(1, 95, 8),
        ],
        splitId: 11,
        dayIndex: 0,
      ),
      _session(now.subtract(const Duration(days: 3)), [
        _set(2, 80, 8),
        _set(3, 0, 10),
      ]),
    ],
    splits: splits ?? [ppl, upperLower],
    currentSplitId: currentSplitId,
    now: now,
  );

  group('ExerciseLibrary', () {
    test('lists every exercise A to Z, ignoring case', () {
      expect(library().exercises.map((e) => e.title), [
        'Barbell Row',
        'Bench Press',
        'cable crunch',
        'Deadlift',
        'Pull Up',
      ]);
    });

    test("keeps each exercise's latest workout and its top set", () {
      final lib = library();
      final benchDay = lib.activityOf(bench)!;
      expect(benchDay.lastTrained, now.subtract(const Duration(days: 1)));
      expect(benchDay.topSet.weight, 100);
      expect(benchDay.topSet.reps, 6);
      expect(lib.activityOf(deadlift)!.topSet.weight, 180);
      expect(lib.activityOf(crunch), isNull);
    });

    test('follows the current split, else the last trained one', () {
      expect(library().split, ppl);
      expect(library(currentSplitId: null).split, upperLower);
      final none = library(splits: const []);
      expect(none.split, isNull);
      expect(none.inSplit(bench), isFalse);
      expect(none.groupsBy(ExerciseGrouping.splitDay), isEmpty);
    });

    test('knows which exercises any day of the split plans', () {
      final lib = library();
      expect(lib.inSplit(bench), isTrue);
      expect(lib.inSplit(row), isTrue);
      expect(lib.inSplit(deadlift), isTrue);
      expect(lib.inSplit(pullUp), isFalse);
      expect(lib.inSplit(crunch), isFalse);
    });

    test('lists recently trained exercises latest first', () {
      expect(library().recentlyTrained.map((e) => e.id), [1, 2, 3, 4]);
    });

    test('groups by muscle group in a set order, broken down by muscle', () {
      final groups = library().groupsBy(ExerciseGrouping.muscle);
      expect(groups.map((g) => g.title), [
        'Chest',
        'Back',
        'Legs',
        'Abdominals',
      ]);
      final back = groups[1];
      expect(back.key, 'muscle-back');
      expect(back.exercises.map((e) => e.title), [
        'Barbell Row',
        'Deadlift',
        'Pull Up',
      ]);
      expect(back.inSplit, 2);
      expect(back.parts, const [
        LibraryPart(label: 'Lower back', total: 1, inSplit: 1),
        LibraryPart(label: 'Lats', total: 2, inSplit: 1),
        LibraryPart(label: 'Traps', total: 1, inSplit: 1),
      ]);
      // Two muscles of one group list the exercise once.
      expect(groups[3].exercises, [crunch]);
      expect(groups[3].inSplit, 0);
      expect(groups[3].parts.map((p) => p.label), ['Abs', 'Obliques']);
    });

    test("groups by the split's days, in the day's order", () {
      final days = library().groupsBy(ExerciseGrouping.splitDay);
      expect(days.map((g) => g.key), ['day-0', 'day-1', 'day-2']);
      expect(days.map((g) => g.title), ['Push', 'Pull', 'Day 3']);
      expect(days[1].exercises, [row]);
      expect(days[2].exercises, [deadlift]);
      expect(days[2].parts, const [
        LibraryPart(label: 'Back', total: 1, inSplit: 1),
        LibraryPart(label: 'Legs', total: 1, inSplit: 1),
      ]);
    });

    test('groups by equipment, broken down by muscle group', () {
      final equipment = library().groupsBy(ExerciseGrouping.equipment);
      expect(equipment.map((g) => g.title), ['Cable', 'Barbell', 'Bodyweight']);
      expect(equipment[1].exercises.length, 3);
      expect(equipment[1].inSplit, 3);
    });

    test('search finds names first, then muscles and equipment', () {
      final lib = library();
      expect(lib.search('  '), lib.exercises);
      expect(lib.search('pull'), [pullUp, row, deadlift]);
      expect(lib.search('bech'), [bench]);
      expect(lib.search('lats'), [row, pullUp]);
      expect(lib.search('cable abs'), [crunch]);
      expect(lib.search('zzz'), isEmpty);
    });
  });

  test('groupExercisesByMuscle lists an exercise once per group', () {
    final grouped = groupExercisesByMuscle([crunch, deadlift]);
    expect(grouped.keys, {
      MuscleGroup.abdominals,
      MuscleGroup.back,
      MuscleGroup.legs,
    });
    expect(grouped[MuscleGroup.abdominals], [crunch]);
  });
}
