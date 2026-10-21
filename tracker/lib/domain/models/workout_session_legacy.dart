import 'package:isar_community/isar.dart';

import 'workout_set.dart';

part 'workout_session_legacy.g.dart';

/// Legacy read-only mirror of the storage schema used before reps were
/// widened from int to double.
///
/// Isar's automatic migration zeroes property values when a property type
/// changes (long → double), so opening the widened schema directly would lose
/// every stored rep count. The reps-widening migration in `DbInstance` reads
/// the old database through these classes first (matching the stored schema,
/// so Isar migrates nothing), then rewrites the sessions after opening the
/// widened schema. Nothing outside that migration path may open these
/// schemas.
@collection
@Name('WorkoutSession')
class WorkoutSessionLegacy {
  WorkoutSessionLegacy({
    this.title = 'Workout',
    required this.startTime,
    this.endTime,
    this.gymId,
    this.sets = const [],
  });

  Id id = Isar.autoIncrement;
  String title;
  DateTime startTime;
  DateTime? endTime;

  /// Foreign key to a [Gym] (see Plan.md §2.2). Null if no gym was recorded.
  int? gymId;

  List<LegacyWorkoutSet> sets;
}

/// Pre-widening mirror of [WorkoutSet]: [reps] is the int it used to be.
@embedded
@Name('WorkoutSet')
class LegacyWorkoutSet {
  LegacyWorkoutSet({
    this.exerciseId = 0,
    this.weight = 0,
    this.reps = 0,
    this.type = SetType.working,
    this.order = 0,
  });

  int exerciseId;
  double weight;
  int reps;
  @enumerated
  SetType type;
  int order;

  bool get isWarmup => type == SetType.warmup;
}
