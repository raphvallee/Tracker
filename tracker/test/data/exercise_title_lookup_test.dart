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
    ], name: 'exercise_title_lookup');
    repo = TrackerRepository(isar);
  });

  tearDown(() => isar.close());

  test(
    'getByTitle detects duplicates case-insensitively, skipping self',
    () async {
      final id = await repo.exercises.put(
        Exercise(
          title: 'Bench Press',
          primaryMuscle: [Muscle.chest],
          equipment: [Equipment.barbell],
          movementPattern: MovementPattern.push,
        ),
      );

      expect((await repo.exercises.getByTitle('bench press'))!.id, id);
      expect((await repo.exercises.getByTitle('BENCH PRESS'))!.id, id);
      expect(await repo.exercises.getByTitle('Squat'), isNull);
      expect(
        await repo.exercises.getByTitle('Bench Press', excludeId: id),
        isNull,
      );
    },
  );
}
