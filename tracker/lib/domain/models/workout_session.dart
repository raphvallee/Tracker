import 'package:isar_community/isar.dart';

import 'workout_set.dart';

part 'workout_session.g.dart';

@collection
class WorkoutSession {
  WorkoutSession({
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

  int? gymId;

  List<WorkoutSet> sets;
}
