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

/// The placeholder for the row at [index] (its position among the
/// exercise's rows): last session's set at that position, else the plan's
/// target reps (a range uses its lower end) with the weight of the row above
/// ([previousWeight]), else the row above's reps.
SetGhost ghostForRow({
  required int index,
  PreviousPerformance? previous,
  List<PlannedSet> planned = const [],
  double? previousWeight,
  double? previousReps,
}) {
  final sets = previous?.sets ?? const <WorkoutSet>[];
  if (index >= 0 && index < sets.length) {
    final set = sets[index];
    return SetGhost(weight: set.weight, reps: set.reps, warmup: set.isWarmup);
  }
  final target = index >= 0 && index < planned.length ? planned[index] : null;
  return SetGhost(
    weight: previousWeight,
    reps: target != null ? target.minReps.toDouble() : previousReps,
  );
}
