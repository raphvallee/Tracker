// One Isar-backed case per file: each *_test.dart runs in its own
// flutter_tester process with a fresh libisar native worker pool (see
// docs/TESTING_ISAR_CI.md).

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/muscle.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/models/workout_split.dart';

import '../../testing/test_helpers.dart';

void main() {
  late Isar isar;
  late TrackerRepository repo;

  setUpAll(initIsarCore);

  setUp(() async {
    isar = await openTestIsar([
      ExerciseSchema,
      GymSchema,
      WorkoutSessionSchema,
      WorkoutSplitSchema,
    ], name: 'exercise_references');
    repo = TrackerRepository(isar);
  });

  tearDown(() => isar.close());

  test('splits and sessions report exercise references', () async {
    final benchId = await repo.exercises.put(
      Exercise(
        title: 'Bench Press',
        primaryMuscle: [Muscle.chest],
        equipment: [Equipment.barbell],
        movementPattern: MovementPattern.push,
      ),
    );
    final squatId = await repo.exercises.put(
      Exercise(
        title: 'Squat',
        primaryMuscle: [Muscle.quadriceps],
        equipment: [Equipment.barbell],
        movementPattern: MovementPattern.legs,
      ),
    );

    expect(await repo.splits.countReferencingSplits(benchId), 0);
    expect(await repo.sessions.countLoggingSessions(benchId), 0);

    await repo.splits.put(
      WorkoutSplit(
        title: 'PPL',
        order: 0,
        splitDays: [
          WorkoutSplitDay(
            title: 'Push',
            order: 0,
            exercises: [ExerciseItem(exerciseId: benchId, order: 0)],
          ),
        ],
      ),
    );
    await repo.splits.put(
      WorkoutSplit(
        title: 'Upper',
        order: 1,
        splitDays: [
          WorkoutSplitDay(
            title: 'Upper',
            order: 0,
            exercises: [ExerciseItem(exerciseId: squatId, order: 0)],
          ),
        ],
      ),
    );
    expect(await repo.splits.countReferencingSplits(benchId), 1);
    expect(await repo.splits.countReferencingSplits(squatId), 1);
    expect(await repo.splits.countReferencingSplits(squatId + 1000), 0);

    final gymId = await repo.gyms.put(Gym(name: 'Home', isPrimary: true));
    await repo.sessions.put(
      WorkoutSession(
        title: 'Squat day',
        startTime: DateTime(2026, 1, 1, 9),
        endTime: DateTime(2026, 1, 1, 10),
        gymId: gymId,
        sets: [
          WorkoutSet(
            exerciseId: squatId,
            weight: 100,
            reps: 5,
            type: SetType.working,
            order: 0,
          ),
        ],
      ),
    );
    await repo.sessions.put(
      WorkoutSession(
        title: 'Bench day',
        startTime: DateTime(2026, 1, 2, 9),
        endTime: DateTime(2026, 1, 2, 10),
        gymId: gymId,
        sets: [
          WorkoutSet(
            exerciseId: benchId,
            weight: 60,
            reps: 8,
            type: SetType.warmup,
            order: 0,
          ),
          WorkoutSet(
            exerciseId: benchId,
            weight: 80,
            reps: 5,
            type: SetType.working,
            order: 1,
          ),
        ],
      ),
    );
    expect(await repo.sessions.countLoggingSessions(benchId), 1);
    expect(await repo.sessions.countLoggingSessions(squatId), 1);
    expect(await repo.sessions.countLoggingSessions(squatId + 1000), 0);
  });
}
