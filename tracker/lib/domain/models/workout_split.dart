import 'package:isar_community/isar.dart';

part 'workout_split.g.dart';

// After changing @collection/@embedded/@enumerated annotations, regenerate with:
//   cd tracker && dart run build_runner build

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

/// One planned set of an [ExerciseItem]: either a fixed rep count
/// ([maxReps] is null) or a rep range `minReps..maxReps`. Embedded, ordered
/// by [order] within the exercise's set list.
@embedded
class PlannedSet {
  PlannedSet({this.order = 0, this.minReps = 0, this.maxReps});

  int order;

  /// Fixed rep count, or the range minimum when [maxReps] is set.
  int minReps;

  /// Range maximum; null means this is a fixed-reps set.
  int? maxReps;
}

extension PlannedSetX on PlannedSet {
  /// Whether this set targets a rep range instead of a fixed rep count.
  bool get isRange => maxReps != null;

  /// Human-readable rep target, e.g. `10` or `8-12`.
  String get repsLabel => maxReps == null ? '$minReps' : '$minReps-$maxReps';
}

/// Compact summary of an exercise's planned sets, e.g. `3 × 8-12` or
/// `3 × 10, 8-12` when the sets differ. Null when there are no sets.
String? plannedSetsSummary(List<PlannedSet> sets) {
  if (sets.isEmpty) return null;
  final labels = sets.map((set) => set.repsLabel).toSet();
  final repsPart = labels.length == 1 ? labels.single : labels.join(', ');
  return '${sets.length} × $repsPart';
}
