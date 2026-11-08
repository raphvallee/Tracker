// Restoring a saved workout takes it out of history.
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
    ], name: 'workout_restore_saved');
    repo = TrackerRepository(isar);
    cubit = WorkoutCubit(repository: repo);
  });

  tearDown(() async {
    await cubit.close();
    await isar.close();
  });

  test('saved workout can always be restored (leaving history)', () async {
    cubit.startPlanWorkout(
      title: 'PPL · Push',
      exercises: const [
        PlanExercise(exerciseId: 1, name: 'Bench Press', order: 0),
      ],
    );
    final originalStart = cubit.state.startTime;
    cubit.logSet(
      exerciseId: 1,
      exerciseName: 'Bench Press',
      weight: 100,
      reps: 5,
    );
    await cubit.endWorkout();

    expect(cubit.state.isInProgress, isFalse);
    expect(cubit.state.canRestoreSaved(), isTrue);
    expect(cubit.state.savedSessionId, isNotNull);

    await cubit.restoreSavedWorkout();

    // The saved session left history and is ongoing again, verbatim,
    // split plan included.
    expect(cubit.state.isInProgress, isTrue);
    expect(cubit.state.planTitle, 'PPL · Push');
    expect(cubit.state.plan.single.name, 'Bench Press');
    expect(cubit.state.sets.single.weight, 100);
    expect(cubit.state.sets.single.reps, 5);
    expect(cubit.state.canRestoreSaved(), isFalse);
    expect(await repo.sessions.getAll(), isEmpty);

    // Re-saving the restored session works and becomes the new restore
    // target - no duplicate entries from the restore round-trip, and the
    // original start time is replayed verbatim (not the restore time).
    await cubit.endWorkout();
    expect(cubit.state.isInProgress, isFalse);
    expect(cubit.state.canRestoreSaved(), isTrue);
    final sessions = await repo.sessions.getAll();
    expect(sessions, hasLength(1));
    expect(sessions.single.sets, hasLength(1));
    expect(sessions.single.startTime, originalStart);
  });
}
