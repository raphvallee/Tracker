// Seeded fixtures shared by the layout-overflow and visual-screenshot sweeps:
// real gyms/split/sessions with deliberately long titles and names designed to
// stress tight card rows. Pure repository logic - no widget coupling.

import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/models/workout_split.dart';

class SweepFixtures {
  SweepFixtures({
    required this.exercises,
    required this.bench,
    required this.benchId,
    required this.inclineId,
    required this.allGyms,
    required this.secondaryGym,
    required this.split,
    required this.session,
    required this.allSessions,
    required this.gymNames,
  });

  final List<Exercise> exercises;
  final Exercise bench;
  final int benchId;
  final int inclineId;
  final List<Gym> allGyms;
  final Gym secondaryGym;
  final WorkoutSplit split;
  final WorkoutSession session;
  final List<WorkoutSession> allSessions;
  final Map<int, String> gymNames;
}

// Single captured 'now': all seeded session times are fixed offsets from it so
// timestamps don't drift between capture sizes (pixel-diff determinism).
final _fixtureNow = DateTime.now();

Future<SweepFixtures> seedSweepFixtures(TrackerRepository repo) async {
  final exercises = await repo.exercises.getAll();
  final bench = exercises.firstWhere((e) => e.title == 'Bench Press');
  final incline = exercises.firstWhere((e) => e.title == 'Incline Bench Press');

  final primaryGym = Gym(name: 'Iron Temple', isPrimary: true, order: 0);
  final secondaryGym = Gym(
    name: 'Very Long Gym Name - Westfield Century City',
    order: 1,
    multiplier: 0.9,
  );
  await repo.gyms.put(primaryGym);
  await repo.gyms.put(secondaryGym);

  final split = WorkoutSplit(
    title: 'Push Pull Legs - Complete Program',
    description: 'A three-day split for the weekday warrior',
    order: 0,
    splitDays: [
      WorkoutSplitDay(
        title: 'Push Day',
        description: 'Chest, shoulders, triceps',
        order: 0,
        exercises: [
          ExerciseItem(
            exerciseId: bench.id,
            order: 0,
            targetSets: 4,
            targetReps: 8,
            sets: [
              for (var i = 0; i < 4; i++)
                PlannedSet(order: i, minReps: 8, maxReps: 12),
            ],
          ),
          ExerciseItem(exerciseId: incline.id, order: 1, targetSets: 3),
        ],
      ),
      WorkoutSplitDay(
        title: 'Pull Day - a rather long day title for overflow checks',
        description: 'Back and biceps',
        order: 1,
        exercises: [ExerciseItem(exerciseId: incline.id, order: 0)],
      ),
    ],
  );
  await repo.splits.put(split);

  final now = _fixtureNow;
  final sessions = <WorkoutSession>[
    WorkoutSession(
      title: 'Push Day',
      startTime: now.subtract(const Duration(days: 1, hours: 2)),
      endTime: now.subtract(const Duration(days: 1)),
      gymId: primaryGym.id,
      sets: [
        WorkoutSet(
          exerciseId: bench.id,
          weight: 60,
          reps: 10,
          type: SetType.warmup,
          order: 0,
        ),
        WorkoutSet(exerciseId: bench.id, weight: 82.5, reps: 8, order: 1),
        WorkoutSet(exerciseId: incline.id, weight: 60, reps: 10, order: 2),
      ],
    ),
    WorkoutSession(
      title: 'Pull Day - Long Session Title Meant To Stress Tight Card Rows',
      startTime: now.subtract(const Duration(days: 3, hours: 1)),
      endTime: now.subtract(const Duration(days: 3)),
      gymId: secondaryGym.id,
      sets: [
        WorkoutSet(exerciseId: incline.id, weight: 40, reps: 12, order: 0),
      ],
    ),
    WorkoutSession(
      title: 'Legs',
      startTime: now.subtract(const Duration(days: 8)),
      endTime: now
          .subtract(const Duration(days: 8))
          .add(const Duration(minutes: 45)),
      gymId: primaryGym.id,
      sets: [],
    ),
  ];
  for (final s in sessions) {
    await repo.sessions.put(s);
  }

  return SweepFixtures(
    exercises: exercises,
    bench: bench,
    benchId: bench.id,
    inclineId: incline.id,
    allGyms: [primaryGym, secondaryGym],
    secondaryGym: secondaryGym,
    split: split,
    session: sessions.first,
    allSessions: sessions,
    gymNames: {
      primaryGym.id: primaryGym.name,
      secondaryGym.id: secondaryGym.name,
    },
  );
}
