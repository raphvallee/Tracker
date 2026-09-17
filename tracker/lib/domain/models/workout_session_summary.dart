import 'package:tracker/domain/models/workout_session.dart';

/// Calendar row data. Embedded sets are decoded only by the selected-day read,
/// counted here, then released rather than cached with calendar presentation.
class WorkoutSessionSummary {
  const WorkoutSessionSummary({
    required this.id,
    required this.title,
    required this.startTime,
    required this.setCount,
    required this.gymId,
  });

  factory WorkoutSessionSummary.fromSession(WorkoutSession session) =>
      WorkoutSessionSummary(
        id: session.id,
        title: session.title,
        startTime: session.startTime,
        setCount: session.sets.length,
        gymId: session.gymId,
      );

  final int id;
  final String title;
  final DateTime startTime;
  final int setCount;
  final int? gymId;
}
