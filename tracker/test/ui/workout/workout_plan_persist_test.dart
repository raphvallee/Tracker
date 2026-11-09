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
    ], name: 'workout_plan_persist');
    repo = TrackerRepository(isar);
    cubit = WorkoutCubit(repository: repo);
  });

  tearDown(() async {
    await cubit.close();
    await isar.close();
  });

  test('a split day workout saves its plan title and split link', () async {
    cubit.startPlanWorkout(
      title: 'Push',
      splitTitle: 'PPL',
      splitId: 12,
      splitDayIndex: 0,
      exercises: const [
        PlanExercise(exerciseId: 1, name: 'Bench Press', order: 0),
        PlanExercise(exerciseId: 2, name: 'OHP', order: 1),
      ],
    );
    expect(cubit.state.plan, hasLength(2));
    expect(cubit.state.planTitle, 'Push');
    expect(cubit.state.plan.first.name, 'Bench Press');

    cubit.logSet(
      exerciseId: 1,
      exerciseName: 'Bench Press',
      weight: 80,
      reps: 6,
    );
    await cubit.endWorkout();

    final session = (await repo.sessions.getAll()).single;
    expect(session.title, 'PPL · Push');
    expect(session.splitId, 12);
    expect(session.splitDayIndex, 0);
    expect(session.sets.single.exerciseId, 1);
    final visits = await repo.sessions.getSplitVisits();
    expect(visits.single.splitId, 12);
  });
}
