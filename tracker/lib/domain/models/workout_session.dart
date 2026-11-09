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
    this.splitId,
    this.splitDayIndex,
  });

  Id id = Isar.autoIncrement;
  String title;
  DateTime startTime;
  DateTime? endTime;

  int? gymId;

  List<WorkoutSet> sets;

  /// The split and day (by position) a session was started from; both null
  /// for empty workouts and sessions saved before splits were tracked. They
  /// drive the Workout tab's "Up next" rotation.
  int? splitId;
  int? splitDayIndex;
}
