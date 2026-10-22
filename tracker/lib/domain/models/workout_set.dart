import 'package:isar_community/isar.dart';

part 'workout_set.g.dart';

/// How a set should be treated for analysis (see Plan.md §2.1).
///
/// Warm-up sets are excluded from progression algorithms, 1RM estimates, peak
/// volume and performance analytics.
enum SetType { warmup, working }

/// A single performed set within a [WorkoutSession]. Embedded inline, so it has
/// no `Id` of its own; [order] preserves sequence and [exerciseId] links back to
/// the [Exercise] performed.
///
/// [reps] is a double: fractional reps (up to two decimal places, e.g. 3.25)
/// are supported. Older databases stored whole-number int reps; Isar's
/// automatic migration loads them as whole doubles (verified by the
/// fixture-backed migration test in test/ui/workout/).
@embedded
class WorkoutSet {
  WorkoutSet({
    this.exerciseId = 0,
    this.weight = 0,
    this.reps = 0,
    this.type = SetType.working,
    this.order = 0,
  });

  int exerciseId;
  double weight;
  double reps;
  @enumerated
  SetType type;
  int order;

  bool get isWarmup => type == SetType.warmup;
}
