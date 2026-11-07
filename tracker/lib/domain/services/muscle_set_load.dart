/// Pure per-muscle set load for a planned day, sorted for display.
library;

import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/muscle.dart';
import 'package:tracker/domain/models/workout_split.dart';

/// Weight of one secondary-muscle set when sorting a muscle that is also hit
/// as a primary muscle.
const double secondarySetWeight = 0.25;

/// One muscle's planned sets, split by whether it is the primary or a
/// secondary target of the exercises that hit it.
class MuscleSetLoad {
  const MuscleSetLoad({
    required this.muscle,
    required this.primarySets,
    required this.secondarySets,
  });

  final Muscle muscle;
  final int primarySets;
  final int secondarySets;

  /// Every planned set that touches the muscle, primary or secondary.
  int get totalSets => primarySets + secondarySets;

  /// Whether the muscle is only ever a secondary target.
  bool get isSecondaryOnly => primarySets == 0;

  /// Sort weight: primary sets at full value, secondary sets at
  /// [secondarySetWeight].
  double get sortWeight => primarySets + secondarySetWeight * secondarySets;
}

/// Totals each muscle's planned sets across [plan] (each exercise paired with
/// its planned set count). A muscle that is primary in any exercise sorts
/// before muscles that are only secondary; within each group, higher
/// [MuscleSetLoad.sortWeight] comes first, then enum order breaks ties.
List<MuscleSetLoad> muscleSetLoads(
  Iterable<({Exercise exercise, int sets})> plan,
) {
  final primary = <Muscle, int>{};
  final secondary = <Muscle, int>{};
  for (final (:exercise, :sets) in plan) {
    for (final muscle in exercise.primaryMuscle) {
      primary.update(muscle, (total) => total + sets, ifAbsent: () => sets);
    }
    for (final muscle in exercise.secondaryMuscle ?? const <Muscle>[]) {
      // A muscle that is primary for this exercise counts once, as primary.
      if (exercise.primaryMuscle.contains(muscle)) continue;
      secondary.update(muscle, (total) => total + sets, ifAbsent: () => sets);
    }
  }

  final loads = [
    for (final muscle in {...primary.keys, ...secondary.keys})
      MuscleSetLoad(
        muscle: muscle,
        primarySets: primary[muscle] ?? 0,
        secondarySets: secondary[muscle] ?? 0,
      ),
  ];
  loads.sort((a, b) {
    final group = (a.isSecondaryOnly ? 1 : 0).compareTo(
      b.isSecondaryOnly ? 1 : 0,
    );
    if (group != 0) return group;
    final weight = b.sortWeight.compareTo(a.sortWeight);
    if (weight != 0) return weight;
    return a.muscle.index.compareTo(b.muscle.index);
  });
  return loads;
}

/// Muscle loads for one split [day]. An item counts its planned sets, or
/// `targetSets` for a legacy item saved before planned sets existed. Items
/// whose exercise is missing from [exercisesById] are skipped.
List<MuscleSetLoad> dayMuscleSetLoads(
  WorkoutSplitDay day,
  Map<int, Exercise> exercisesById,
) => muscleSetLoads([
  for (final item in day.exercises)
    if (exercisesById[item.exerciseId] case final exercise?)
      (exercise: exercise, sets: _plannedSetCount(item)),
]);

int _plannedSetCount(ExerciseItem item) =>
    item.sets.isNotEmpty ? item.sets.length : (item.targetSets ?? 0);
