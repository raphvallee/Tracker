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
  });

  Id id = Isar.autoIncrement;
  String name;
  String? description;
  bool isPrimary;
  int order;

  double multiplier;

  List<GymExerciseMultiplier> perExerciseMultipliers;
}

@embedded
class GymExerciseMultiplier {
  GymExerciseMultiplier({this.exerciseId = 0, this.multiplier = 1.0});

  int exerciseId;
  double multiplier;
}
