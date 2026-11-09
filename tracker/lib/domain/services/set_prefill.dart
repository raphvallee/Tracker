import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/models/workout_split.dart';

/// The sets one exercise got in the last session that logged it.
class PreviousPerformance {
  const PreviousPerformance({required this.date, required this.sets});

  final DateTime date;

  /// In logged order.
  final List<WorkoutSet> sets;

  /// Warm-ups logged before the first working set.
  int get leadingWarmups {
    var count = 0;
    for (final set in sets) {
      if (!set.isWarmup) break;
      count++;
    }
    return count;
  }
}

/// Placeholder values for a set row that is not logged yet.
class SetGhost {
  const SetGhost({this.weight, this.reps, this.warmup = false});

  /// Kilograms.
  final double? weight;
  final double? reps;
  final bool warmup;

  static const none = SetGhost();
}

/// Rows before the first planned one: last session's opening warm-ups, when
/// a plan with no warm-ups of its own is prefilled from it ([previous]).
int leadingWarmupRows(
  List<PlannedSet> planned,
  PreviousPerformance? previous,
) => planned.isEmpty || planned.any((set) => set.isWarmup)
    ? 0
    : previous?.leadingWarmups ?? 0;

/// The planned set the row at [index] stands for, after [lead] rows that
/// stand for none (see [leadingWarmupRows]).
PlannedSet? plannedForRow(int index, List<PlannedSet> planned, {int lead = 0}) {
  final at = index - lead;
  return at >= 0 && at < planned.length ? planned[at] : null;
}

/// The placeholder for the row at [index] (its position among the
/// exercise's rows): last session's set at that position, else the plan's
/// target reps (a range uses its lower end) with the weight of the row above
/// ([previousWeight]), else the row above's reps. A planned set decides the
/// row's type; else last session's set does.
SetGhost ghostForRow({
  required int index,
  PreviousPerformance? previous,
  List<PlannedSet> planned = const [],
  int lead = 0,
  double? previousWeight,
  double? previousReps,
}) {
  final sets = previous?.sets ?? const <WorkoutSet>[];
  final target = plannedForRow(index, planned, lead: lead);
  if (index >= 0 && index < sets.length) {
    final set = sets[index];
    return SetGhost(
      weight: set.weight,
      reps: set.reps,
      warmup: target?.isWarmup ?? set.isWarmup,
    );
  }
  return SetGhost(
    weight: previousWeight,
    reps: target != null ? target.minReps.toDouble() : previousReps,
    warmup: target?.isWarmup ?? false,
  );
}
