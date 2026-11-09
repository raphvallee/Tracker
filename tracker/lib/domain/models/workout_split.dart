import 'package:isar_community/isar.dart';

part 'workout_split.g.dart';

@collection
class WorkoutSplit {
  WorkoutSplit({
    this.title = "Split",
    this.description = "",
    this.splitDays = const [],
    this.order = -1,
  });

  Id id = Isar.autoIncrement;
  String title;
  String description;
  List<WorkoutSplitDay> splitDays;
  int order;
}

@embedded
class WorkoutSplitDay {
  WorkoutSplitDay({
    this.title = "Split Day",
    this.description = "",
    this.exercises = const [],
    this.order = -1,
  });

  String title;
  String description;
  List<ExerciseItem> exercises;
  int order;
}

/// An exercise within a split day: links to an [Exercise] by id plus per-slot
/// guidance. Embedded, so ordered by [order] rather than an `Id`.
///
/// The planned sets live in [sets] (see [PlannedSet]); every exercise must
/// carry at least one set. `targetSets`/`targetReps`/`restSeconds` are legacy
/// pre-1.0 fields (schema freeze forbids deletion) that are no longer written
/// by the editor.
@embedded
class ExerciseItem {
  ExerciseItem({
    this.exerciseId = 0,
    this.order = 0,
    this.targetSets,
    this.targetReps,
    this.restSeconds,
    this.sets = const [],
  });

  int exerciseId;
  int order;
  int? targetSets;
  int? targetReps;
  int? restSeconds;
  List<PlannedSet> sets;
}

@embedded
class PlannedSet {
  PlannedSet({
    this.order = 0,
    this.minReps = 0,
    this.maxReps,
    this.isWarmup = false,
  });

  int order;

  int minReps;

  int? maxReps;

  /// A warm-up, not counted among the exercise's working sets. Sets saved
  /// before warm-ups could be planned read as working sets.
  bool isWarmup;
}

extension PlannedSetX on PlannedSet {
  bool get isRange => maxReps != null;

  String get repsLabel => maxReps == null ? '$minReps' : '$minReps-$maxReps';

  String get repsUnit => !isRange && minReps == 1 ? 'rep' : 'reps';
}

bool exercisePlanEquals(List<ExerciseItem> a, List<ExerciseItem> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].exerciseId != b[i].exerciseId) return false;
    if (a[i].sets.length != b[i].sets.length) return false;
    for (var j = 0; j < a[i].sets.length; j++) {
      if (a[i].sets[j].minReps != b[i].sets[j].minReps ||
          a[i].sets[j].maxReps != b[i].sets[j].maxReps) {
        return false;
      }
    }
  }
  return true;
}

bool splitDayPlanEquals(WorkoutSplitDay a, WorkoutSplitDay b) =>
    a.title == b.title &&
    a.description == b.description &&
    exercisePlanEquals(a.exercises, b.exercises);
