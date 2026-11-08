// One Isar-backed case per file: each *_test.dart runs in its own
// flutter_tester process with a fresh libisar native worker pool (see
// docs/TESTING_ISAR_CI.md).

import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:isar_community/isar.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
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
    ], name: 'workout_end_persist');
    repo = TrackerRepository(isar);
    cubit = WorkoutCubit(repository: repo);
  });

  tearDown(() async {
    await cubit.close();
    await isar.close();
  });

  test('start → log working + warmup → persist session to Isar', () async {
    final gymId = await repo.gyms.put(Gym(name: 'Home', isPrimary: true));
    final gym = (await repo.gyms.getById(gymId))!;

    cubit.startWorkout(gym: gym);
    expect(cubit.state.isInProgress, isTrue);
    expect(cubit.state.gymId, gymId);

    cubit.logSet(exerciseId: 1, exerciseName: 'Squat', weight: 100, reps: 5);
    cubit.logSet(
      exerciseId: 1,
      exerciseName: 'Squat',
      weight: 60,
      reps: 8,
      type: SetType.warmup,
    );
    cubit.logSet(exerciseId: 1, exerciseName: 'Squat', weight: 100, reps: 5);
    expect(cubit.state.sets, hasLength(3));
    expect(cubit.state.sets[1].isWarmup, isTrue);

    final started = DateTime.now();
    await cubit.endWorkout();

    expect(cubit.state.isInProgress, isFalse);
    final sessions = await repo.sessions.getAll();
    expect(sessions, hasLength(1));

    final session = sessions.first;
    expect(session.title, 'Home workout');
    expect(session.gymId, gymId);
    expect(session.sets, hasLength(3));
    expect(session.sets[1].type, SetType.warmup);
    expect(session.endTime, isNotNull);
    expect(
      session.endTime!.difference(session.startTime),
      isNot(greaterThan(const Duration(minutes: 1))),
      reason: 'duration should be ~(now - start) for a quick test session',
    );
    expect(started.difference(session.startTime).inSeconds, lessThan(60));
  });
}
