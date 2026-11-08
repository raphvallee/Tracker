// A discarded workout is restorable for 15 minutes, never persisted.
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
    ], name: 'workout_restore_discarded');
    repo = TrackerRepository(isar);
    cubit = WorkoutCubit(repository: repo);
  });

  tearDown(() async {
    await cubit.close();
    await isar.close();
  });

  test('discarded workout is restorable only within 15 minutes', () async {
    var now = DateTime(2026, 9, 3, 10);
    final timed = WorkoutCubit(repository: repo, now: () => now);
    addTearDown(timed.close);

    timed.startWorkout();
    timed.logSet(exerciseId: 1, exerciseName: 'Squat', weight: 100, reps: 5);
    await timed.discardWorkout();

    // Never persisted, but held in memory for the window.
    expect(timed.state.isInProgress, isFalse);
    expect(timed.state.canRestoreDiscarded(now: now), isTrue);
    expect(timed.state.savedSnapshot, isNull);
    expect(await repo.sessions.getAll(), isEmpty);

    timed.restoreDiscardedWorkout();
    expect(timed.state.isInProgress, isTrue);
    expect(timed.state.sets.single.weight, 100);
    expect(timed.state.canRestoreDiscarded(now: now), isFalse);

    // Discard again and let the window lapse: restore becomes a no-op and
    // drops the stale snapshot.
    await timed.discardWorkout();
    now = now.add(const Duration(minutes: 16));
    expect(timed.state.canRestoreDiscarded(now: now), isFalse);
    timed.restoreDiscardedWorkout();
    expect(timed.state.isInProgress, isFalse);
    expect(timed.state.discardedSnapshot, isNull);
    expect(timed.state.discardedAt, isNull);
  });
}
