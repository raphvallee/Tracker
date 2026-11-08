import 'package:isar_community/isar.dart';

import 'muscle.dart';

part 'exercise.g.dart';

@collection
class Exercise {
  Exercise({
    required this.title,
    required this.primaryMuscle,
    required this.equipment,
    this.description,
    this.secondaryMuscle,
    this.movementPattern = MovementPattern.unspecified,
  });

  Id id = Isar.autoIncrement;
  String title;
  String? description;
  @enumerated
  List<Muscle> primaryMuscle;
  @enumerated
  List<Muscle>? secondaryMuscle;
  @enumerated
  List<Equipment> equipment;
  @enumerated
  MovementPattern movementPattern;
}

enum MovementPattern { unspecified, push, pull, legs, core, fullBody }

enum Equipment {
  dumbbell(displayName: 'Dumbbell'),
  barbell(displayName: 'Barbell'),
  machine(displayName: 'Machine'),
  bodyweight(displayName: 'Bodyweight'),
  cable(displayName: 'Cable');

  const Equipment({required this.displayName});

  final String displayName;
}
