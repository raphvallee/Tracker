import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/muscle.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/domain/services/muscle_set_load.dart';

Exercise _exercise(
  String title, {
  required List<Muscle> primary,
  List<Muscle> secondary = const [],
}) => Exercise(
  title: title,
  primaryMuscle: primary,
  secondaryMuscle: secondary,
  equipment: const [],
);

List<Muscle> _order(List<MuscleSetLoad> loads) => [
  for (final load in loads) load.muscle,
];

void main() {
  group('muscleSetLoads', () {
    test('returns nothing for an empty plan', () {
      expect(muscleSetLoads(const []), isEmpty);
    });

    test('puts secondary-only muscles after every primary muscle', () {
      final loads = muscleSetLoads([
        (
          exercise: _exercise(
            'Bench',
            primary: [Muscle.chest],
            secondary: [Muscle.triceps],
          ),
          sets: 3,
        ),
        (exercise: _exercise('Squat', primary: [Muscle.quadriceps]), sets: 1),
      ]);

      // Triceps has more sets than quadriceps but is secondary-only.
      expect(_order(loads), [Muscle.chest, Muscle.quadriceps, Muscle.triceps]);
    });

    test('weights secondary sets at 0.25 for muscles also hit as primary', () {
      final loads = muscleSetLoads([
        (exercise: _exercise('Dip', primary: [Muscle.chest]), sets: 2),
        (exercise: _exercise('Pushdown', primary: [Muscle.triceps]), sets: 2),
        (
          exercise: _exercise(
            'Bench',
            primary: [Muscle.chest],
            secondary: [Muscle.triceps],
          ),
          sets: 2,
        ),
        (
          exercise: _exercise('Leg press', primary: [Muscle.quadriceps]),
          sets: 2,
        ),
      ]);

      // Triceps: 2 primary + 2 secondary * 0.25 = 2.5. Chest: 2 + 2 = 4.0.
      // At full weight triceps would be 4.0 and tie chest, falling back to
      // enum order (triceps before chest), so the expected order separates
      // the two rules.
      final triceps = loads.firstWhere((l) => l.muscle == Muscle.triceps);
      expect(triceps.primarySets, 2);
      expect(triceps.secondarySets, 2);
      expect(triceps.sortWeight, 2.5);
      expect(_order(loads), [Muscle.chest, Muscle.triceps, Muscle.quadriceps]);
    });

    test('orders secondary-only muscles by their set count', () {
      final loads = muscleSetLoads([
        (
          exercise: _exercise(
            'Row',
            primary: [Muscle.lats],
            secondary: [Muscle.biceps, Muscle.lowerBack],
          ),
          sets: 4,
        ),
        (
          exercise: _exercise(
            'Press',
            primary: [Muscle.chest],
            secondary: [Muscle.frontDelts],
          ),
          sets: 2,
        ),
      ]);

      expect(_order(loads), [
        Muscle.lats,
        Muscle.chest,
        Muscle.biceps,
        Muscle.lowerBack,
        Muscle.frontDelts,
      ]);
    });

    test('counts a muscle listed as both primary and secondary once', () {
      final loads = muscleSetLoads([
        (
          exercise: _exercise(
            'Odd',
            primary: [Muscle.chest],
            secondary: [Muscle.chest],
          ),
          sets: 3,
        ),
      ]);

      expect(loads, hasLength(1));
      expect(loads.single.primarySets, 3);
      expect(loads.single.secondarySets, 0);
      expect(loads.single.sortWeight, 3.0);
    });

    test('row count is primary sets plus secondary sets', () {
      final loads = muscleSetLoads([
        (exercise: _exercise('Dips', primary: [Muscle.triceps]), sets: 2),
        (
          exercise: _exercise(
            'Bench',
            primary: [Muscle.chest],
            secondary: [Muscle.triceps],
          ),
          sets: 2,
        ),
      ]);

      final triceps = loads.firstWhere((l) => l.muscle == Muscle.triceps);
      expect(triceps.primarySets, 2);
      expect(triceps.secondarySets, 2);
      expect(triceps.totalSets, 4);
    });
  });

  group('dayMuscleSetLoads', () {
    final bench = _exercise(
      'Bench',
      primary: [Muscle.chest],
      secondary: [Muscle.triceps],
    );
    final pushdown = _exercise('Pushdown', primary: [Muscle.triceps]);

    test('counts each item by its planned sets', () {
      final day = WorkoutSplitDay(
        title: 'Push',
        description: '',
        order: 0,
        exercises: [
          ExerciseItem(
            exerciseId: 1,
            sets: [PlannedSet(), PlannedSet(order: 1), PlannedSet(order: 2)],
          ),
          ExerciseItem(
            exerciseId: 2,
            order: 1,
            sets: [PlannedSet(), PlannedSet(order: 1)],
          ),
        ],
      );

      final loads = dayMuscleSetLoads(day, {1: bench, 2: pushdown});

      final chest = loads.firstWhere((l) => l.muscle == Muscle.chest);
      expect(chest.totalSets, 3);
      final triceps = loads.firstWhere((l) => l.muscle == Muscle.triceps);
      expect(triceps.primarySets, 2);
      expect(triceps.secondarySets, 3);
      expect(triceps.totalSets, 5);
    });

    test('falls back to targetSets for a legacy item without sets', () {
      final day = WorkoutSplitDay(
        title: 'Push',
        description: '',
        order: 0,
        exercises: [ExerciseItem(exerciseId: 1, targetSets: 4)],
      );

      final loads = dayMuscleSetLoads(day, {1: bench});

      expect(loads.firstWhere((l) => l.muscle == Muscle.chest).totalSets, 4);
    });

    test('skips items whose exercise is missing', () {
      final day = WorkoutSplitDay(
        title: 'Push',
        description: '',
        order: 0,
        exercises: [
          ExerciseItem(exerciseId: 1, sets: [PlannedSet()]),
          ExerciseItem(exerciseId: 99, order: 1, sets: [PlannedSet()]),
        ],
      );

      final loads = dayMuscleSetLoads(day, {1: bench});

      expect(_order(loads), [Muscle.chest, Muscle.triceps]);
      expect(loads.every((l) => l.totalSets == 1), isTrue);
    });
  });
}
