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
  });

  int exerciseId;
  double weight;
  double reps;
  @enumerated
  SetType type;
  int order;

  bool get isWarmup => type == SetType.warmup;
}
