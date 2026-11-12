// One Isar-backed case per file: each *_test.dart runs in its own
// flutter_tester process with a fresh libisar native worker pool (see
// docs/TESTING_ISAR_CI.md).

import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:isar_community/isar.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/test_helpers.dart';

void main() {
  late Isar isar;
  late TrackerRepository repo;
  late WorkoutCubit cubit;

  setUpAll(initIsarCore);

  setUp(() async {
    HydratedBloc.storage = InMemoryStorage();
    isar = await openTestIsar([
      WorkoutSessionSchema,
      GymSchema,
    ], name: 'workout_failed_save');
    repo = TrackerRepository(isar);
    cubit = WorkoutCubit(repository: repo);
  });

  tearDown(() async {
    await cubit.close();
    await isar.close();
  });

  test(
    'failed save keeps the in-progress workout and surfaces an error',
    () async {
      final gymId = await repo.gyms.put(Gym(name: 'Home', isPrimary: true));
      final gym = (await repo.gyms.getById(gymId))!;

      cubit.startWorkout(gym: gym);
      cubit.logSet(exerciseId: 1, exerciseName: 'Squat', weight: 100, reps: 5);
      expect(cubit.state.sets, hasLength(1));

      await isar.close();
      await cubit.endWorkout();

      expect(cubit.state.isInProgress, isTrue);
      expect(cubit.state.sets, hasLength(1));
      expect(cubit.state.saveError, isNotNull);

      // Give the shared tearDown a live instance to close again.
      isar = await openTestIsar([
        WorkoutSessionSchema,
        GymSchema,
      ], name: 'workout_failed_save_reopened');
    },
  );
}
