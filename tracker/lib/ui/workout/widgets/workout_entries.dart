import 'dart:math' as math;

import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

/// One exercise of the running workout, as the overview lists it.
class WorkoutEntry {
  const WorkoutEntry({
    required this.exercise,
    required this.sets,
    this.listed = true,
  });

  final PlanExercise exercise;
  final List<ActiveSet> sets;

  /// False for sets logged without a card of their own (sessions saved
  /// before free workouts kept their exercises): they cannot be reordered.
  final bool listed;

  /// Planned working sets: planned warm-ups do not count.
  int get planned => exercise.sets.where((set) => !set.isWarmup).length;

  int get workingLogged => sets.where((set) => !set.isWarmup).length;

  bool get isDone => planned > 0 && workingLogged >= planned;

  /// Planned sets are still open; an exercise with no plan has work left
  /// until its first set is logged.
  bool get hasWorkLeft => planned > 0 ? !isDone : sets.isEmpty;

  /// How far along the exercise is, from 0 to 1.
  double get progress => planned > 0
      ? math.min(workingLogged, planned) / planned
      : (sets.isEmpty ? 0 : 1);
}

/// The running workout's exercises in card order.
List<WorkoutEntry> workoutEntries(WorkoutState state) {
  final grouped = state.setsByExercise;
  final listed = {for (final exercise in state.plan) exercise.exerciseId};
  return [
    for (final exercise in state.plan)
      WorkoutEntry(
        exercise: exercise,
        sets: grouped[exercise.exerciseId] ?? const [],
      ),
    for (final MapEntry(key: id, value: sets) in grouped.entries)
      if (!listed.contains(id))
        WorkoutEntry(
          exercise: PlanExercise(
            exerciseId: id,
            name: sets.first.exerciseName,
            order: state.plan.length,
          ),
          sets: sets,
          listed: false,
        ),
  ];
}

/// Working sets logged toward the plan, out of the plan's sets. Warm-ups
/// and sets beyond the plan do not move it.
({int done, int total}) plannedProgress(List<WorkoutEntry> entries) {
  var done = 0;
  var total = 0;
  for (final entry in entries) {
    if (entry.planned == 0) continue;
    total += entry.planned;
    done += math.min(entry.workingLogged, entry.planned);
  }
  return (done: done, total: total);
}

/// The exercise to move on to from the one at [index]: the next one with
/// work left, looking after it first, then before it. Null when every other
/// exercise is done.
WorkoutEntry? nextEntryAfter(List<WorkoutEntry> entries, int index) {
  for (var step = 1; step < entries.length; step++) {
    final entry = entries[(index + step) % entries.length];
    if (entry.hasWorkLeft) return entry;
  }
  return null;
}
