import 'package:isar_community/isar.dart';

part 'gym.g.dart';

@collection
class Gym {
  Gym({
    required this.name,
    this.description,
    this.isPrimary = false,
    this.order = -1,
    this.multiplier = 1.0,
    this.perExerciseMultipliers = const [],
    this.machineSetups = const [],
  });

  Id id = Isar.autoIncrement;
  String name;
  String? description;
  bool isPrimary;
  int order;

  /// The gym's overall factor: what machines and cables not trained here
  /// yet go by (see `gym_equivalence.dart`).
  double multiplier;

  /// A factor per machine or cable exercise: estimated from workouts here
  /// and at the primary gym, or set by hand.
  List<GymExerciseMultiplier> perExerciseMultipliers;

  /// How each machine is set up here (seat 4, pad 2), one per exercise.
  List<GymMachineSetup> machineSetups;
}

@embedded
class GymExerciseMultiplier {
  GymExerciseMultiplier({
    this.exerciseId = 0,
    this.multiplier = 1.0,
    this.manual = false,
    this.estimate,
    this.samples = 0,
    this.spread = 0,
  });

  int exerciseId;

  /// The factor in use: [estimate], or the one set by hand when [manual].
  double multiplier;

  /// Set by hand: a new estimate updates [estimate], never [multiplier].
  bool manual;

  /// The latest estimate from workouts here; null before there is one.
  double? estimate;

  /// The workouts here [estimate] came from.
  int samples;

  /// How far those workouts typically sit from [estimate].
  double spread;
}

@embedded
class GymMachineSetup {
  GymMachineSetup({this.exerciseId = 0, this.note = ''});

  int exerciseId;
  String note;
}
