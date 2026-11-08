// ExerciseRepository.watchAll emissions.
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
    ], name: 'exercise_watcher');
    repo = TrackerRepository(isar);
  });

  tearDown(() => isar.close());

  test(
    'repository exercise watcher emits initial and updated values',
    () async {
      final values = <List<Exercise>>[];
      final subscription = repo.exercises.watchAll().listen(values.add);
      addTearDown(subscription.cancel);

      await waitFor(() => values.isNotEmpty);
      expect(values.last, isEmpty);

      await repo.exercises.put(
        Exercise(
          title: 'Test Squat',
          primaryMuscle: [Muscle.quadriceps],
          equipment: [Equipment.barbell],
          movementPattern: MovementPattern.legs,
        ),
      );
      await waitFor(() => values.any((list) => list.length == 1));
      expect(values.last.single.title, 'Test Squat');
    },
  );
}
