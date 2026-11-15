import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/services/gym_equivalence.dart';

/// Works every gym's machine and cable factors out again from all sessions
/// (see [refreshedFactors]), and each gym's overall factor as the median of
/// its estimates. Runs when a workout is saved, edited or deleted, and when
/// the primary gym changes: a workout at home moves the trend every other
/// gym is measured against. [effectiveReps] is the setting of that name:
/// rated sets count their reps in reserve too.
Future<void> refreshGymFactors(
  TrackerRepository repo, {
  DateTime? now,
  bool effectiveReps = false,
}) async {
  final (sessions, exercises) = await (
    repo.sessions.getAll(),
    repo.exercises.getAll(),
  ).wait;
  final machines = [
    for (final exercise in exercises)
      if (convertsAcrossGyms(exercise.equipment)) exercise.id,
  ];
  // The gyms are read in the write itself: a factor set by hand meanwhile
  // is kept.
  await repo.gyms.updateAll((gyms) {
    Gym? home;
    for (final gym in gyms) {
      if (gym.isPrimary) home = gym;
    }
    if (home == null) return const [];
    return [
      for (final gym in gyms)
        if (!gym.isPrimary)
          _refreshed(
            gym,
            sessions,
            home.id,
            machines,
            now: now,
            effectiveReps: effectiveReps,
          ),
    ];
  });
}

Gym _refreshed(
  Gym gym,
  List<WorkoutSession> sessions,
  int homeId,
  List<int> machines, {
  DateTime? now,
  bool effectiveReps = false,
}) {
  gym.perExerciseMultipliers = refreshedFactors(
    gym,
    sessions,
    homeGymId: homeId,
    exerciseIds: machines,
    now: now,
    effectiveReps: effectiveReps,
  );
  if (overallFactorOf(gym.perExerciseMultipliers) case final overall?) {
    gym.multiplier = overall;
  }
  return gym;
}
