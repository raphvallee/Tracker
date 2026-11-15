import 'dart:math' as math;

import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/domain/services/analytics.dart';

/// The sets one exercise got in the last session that logged it.
class PreviousPerformance {
  const PreviousPerformance({
    required this.date,
    required this.sets,
    this.gymId,
  });

  final DateTime date;

  /// The gym it was done at; null for sessions logged without one.
  final int? gymId;

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

  /// The heaviest working set, the one with more reps among equals: what
  /// "last time" means in one line. Null when only warm-ups were logged.
  WorkoutSet? get topSet {
    WorkoutSet? top;
    for (final set in sets) {
      if (set.isWarmup) continue;
      if (top == null ||
          set.weight > top.weight ||
          (set.weight == top.weight && set.reps > top.reps)) {
        top = set;
      }
    }
    return top;
  }

  /// The same sets with each weight passed through [weight]: how they read
  /// at another gym.
  PreviousPerformance withWeights(double Function(double kilograms) weight) =>
      PreviousPerformance(
        date: date,
        gymId: gymId,
        sets: [
          for (final set in sets)
            WorkoutSet(
              exerciseId: set.exerciseId,
              weight: weight(set.weight),
              reps: set.reps,
              type: set.type,
              order: set.order,
              rpe: set.rpe,
            ),
        ],
      );
}

/// How far today's sets landed from the weights last time's suggested: the
/// latest logged working set ([logged], by row) over last time's set at its
/// row ([last]), when that was a working set too. 1 when none compares. The
/// pending rows carry it, so a first set heavier than the guess for this gym
/// brings the rest along. With [effectiveReps], a set rated very easy or
/// very hard moves them too (see [_effortCorrection]).
double loggedCorrection(
  List<({double weight, double reps, double? rpe, bool warmup})> logged,
  List<WorkoutSet> last, {
  bool effectiveReps = false,
}) {
  for (var i = math.min(logged.length, last.length) - 1; i >= 0; i--) {
    final now = logged[i];
    final then = last[i];
    if (now.warmup || then.isWarmup) continue;
    if (now.weight <= 0 || then.weight <= 0) return 1;
    final effort = effectiveReps
        ? _effortCorrection(now.reps, now.rpe, then.rpe)
        : 1.0;
    return (now.weight / then.weight * effort).clamp(0.5, 2.0);
  }
  return 1;
}

/// Ratings at or past these say the weight was off, not a usual day.
const double _easyRpe = 6;
const double _hardRpe = 10;

/// What a working set logged without a rating is taken to have felt like.
const double _typicalRpe = 8;

/// How much more the next sets can take after a set of [reps] rated [rpe],
/// against last time's rating ([expected]; [_typicalRpe] without one), both
/// read as effective reps ([effectiveRepsOf]): RPE 6 where 8 was expected
/// makes 10 reps count as 14 against 12, so about 5% more. 1 unless the set
/// was rated very easy or very hard: a rating in between is a usual day.
double _effortCorrection(double reps, double? rpe, double? expected) {
  if (rpe == null || (rpe > _easyRpe && rpe < _hardRpe)) return 1;
  double capacity(double rating) =>
      epley1rm(weight: 1, reps: effectiveRepsOf(reps, rating));
  return capacity(rpe) / capacity(expected ?? _typicalRpe);
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
