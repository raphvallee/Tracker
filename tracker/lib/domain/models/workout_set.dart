import 'package:isar_community/isar.dart';

part 'workout_set.g.dart';

enum SetType { warmup, working }

@embedded
class WorkoutSet {
  WorkoutSet({
    this.exerciseId = 0,
    this.weight = 0,
    this.reps = 0,
    this.type = SetType.working,
    this.order = 0,
    this.rpe,
  });

  int exerciseId;
  double weight;
  double reps;
  @enumerated
  SetType type;
  int order;

  /// How hard the set was, as RPE (0 to 10); null when not rated. Settings
  /// can show it as reps in reserve instead (10 minus RPE).
  double? rpe;

  bool get isWarmup => type == SetType.warmup;
}
