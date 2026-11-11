import 'package:tracker/domain/models/workout_set.dart';

/// One exercise of a past workout: its sets in the order they were logged.
class ExerciseSets {
  const ExerciseSets({required this.exerciseId, required this.sets});

  final int exerciseId;
  final List<WorkoutSet> sets;

  int get workingCount => sets.where((set) => !set.isWarmup).length;

  int get warmupCount => sets.length - workingCount;

  /// The set that stands for the exercise in one line (see [topSetOf]).
  WorkoutSet? get topSet => topSetOf(sets);
}

/// [sets] grouped under their exercise, in the order the exercises were
/// first logged. Each group keeps its sets in logged order.
List<ExerciseSets> groupByExercise(Iterable<WorkoutSet> sets) {
  final grouped = <int, List<WorkoutSet>>{};
  for (final set in sets) {
    (grouped[set.exerciseId] ??= <WorkoutSet>[]).add(set);
  }
  return [
    for (final MapEntry(key: id, value: sets) in grouped.entries)
      ExerciseSets(exerciseId: id, sets: sets),
  ];
}

/// The heaviest working set, the one with more reps among equals. When only
/// warm-ups were logged, the heaviest of those. Null for no sets.
WorkoutSet? topSetOf(Iterable<WorkoutSet> sets) {
  WorkoutSet? top;
  WorkoutSet? topWarmup;
  for (final set in sets) {
    if (set.isWarmup) {
      if (_heavier(set, topWarmup)) topWarmup = set;
    } else if (_heavier(set, top)) {
      top = set;
    }
  }
  return top ?? topWarmup;
}

bool _heavier(WorkoutSet set, WorkoutSet? than) =>
    than == null ||
    set.weight > than.weight ||
    (set.weight == than.weight && set.reps > than.reps);

/// Sets that count: warm-ups left out.
int workingSetCount(Iterable<WorkoutSet> sets) =>
    sets.where((set) => !set.isWarmup).length;

/// Kilograms lifted in working sets: weight times reps, warm-ups left out.
double workingVolumeOf(Iterable<WorkoutSet> sets) => sets
    .where((set) => !set.isWarmup)
    .fold<double>(0, (sum, set) => sum + set.weight * set.reps);

/// The exercises of a workout in one line: "Bench press, Overhead press and
/// 3 more"; two or fewer are just listed.
String exercisePreview(List<String> names, {int shown = 2}) {
  if (names.isEmpty) return 'No sets logged';
  if (names.length <= shown) return names.join(', ');
  return '${names.take(shown).join(', ')} and ${names.length - shown} more';
}

/// An exercise's sets in one line: "4 sets, 2 warm-ups", working sets first
/// and warm-ups only when there are.
String setCountsLabel(int working, int warmups) {
  String count(int n, String noun) => n == 1 ? '1 $noun' : '$n ${noun}s';
  if (working == 0) return count(warmups, 'warm-up');
  final sets = count(working, 'set');
  return warmups == 0 ? sets : '$sets, ${count(warmups, 'warm-up')}';
}
