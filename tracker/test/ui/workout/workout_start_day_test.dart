// One Isar-backed case per file: each *_test.dart runs in its own
// flutter_tester process with a fresh libisar native worker pool (see
// docs/TESTING_ISAR_CI.md).

import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/muscle.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_split.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/isar_app_helpers.dart';
import '../../../testing/test_helpers.dart';
import '../../../testing/workout_helpers.dart';

void main() {
  setUpAll(initIsarCore);
  setUp(() => HydratedBloc.storage = InMemoryStorage());

  testWidgets('the day due is up next; a tap starts a day, a hold previews', (
    tester,
  ) async {
    useTallWindow(tester);
    late TrackerRepository repo;
    late WorkoutSplit split;
    late Gym home;
    await tester.runAsync(() async {
      final isar = await openTestIsar([
        ExerciseSchema,
        GymSchema,
        WorkoutSessionSchema,
        WorkoutSplitSchema,
      ], name: 'workout_start_day');
      repo = TrackerRepository(isar);
      final bench = await repo.exercises.put(
        Exercise(
          title: 'Bench Press',
          primaryMuscle: [Muscle.chest],
          equipment: [Equipment.barbell],
        ),
      );
      final row = await repo.exercises.put(
        Exercise(
          title: 'Barbell Row',
          primaryMuscle: [Muscle.lats],
          equipment: [Equipment.barbell],
        ),
      );
      await repo.gyms.put(Gym(name: 'Iron Temple', isPrimary: true, order: 0));
      home = Gym(name: 'Home', order: 1);
      await repo.gyms.put(home);
      split = WorkoutSplit(
        title: 'PPL',
        order: 0,
        splitDays: [
          WorkoutSplitDay(
            title: 'Push',
            exercises: [
              ExerciseItem(
                exerciseId: bench,
                sets: [
                  for (var i = 0; i < 3; i++)
                    PlannedSet(order: i, minReps: 8, maxReps: 12),
                ],
              ),
            ],
          ),
          WorkoutSplitDay(
            title: 'Pull',
            exercises: [
              ExerciseItem(exerciseId: row, sets: [PlannedSet(minReps: 10)]),
            ],
          ),
          WorkoutSplitDay(title: 'Legs'),
        ],
      );
      await repo.splits.put(split);
      // Push was trained yesterday: Pull is due.
      await repo.sessions.put(
        WorkoutSession(
          title: 'PPL · Push',
          startTime: DateTime.now().subtract(const Duration(days: 1)),
          splitId: split.id,
          splitDayIndex: 0,
        ),
      );
    });

    final app = await pumpRealApp(tester, repo);
    await pumpUntil(tester, find.byType(FBottomNavigationBar));
    tester
        .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
        .onChange!(2);
    await pumpUntil(tester, find.text('Start Pull'));

    expect(find.text('Up next in PPL'), findsOneWidget);
    expect(find.text('Barbell Row'), findsOneWidget);
    expect(find.text('1 exercise, 1 set. Not done yet.'), findsOneWidget);
    expect(find.text('Iron Temple'), findsOneWidget, reason: 'primary gym');
    expect(find.textContaining('last done yesterday'), findsOneWidget);
    expect(
      find.text('Tap a day to start it. Hold it to preview.'),
      findsOneWidget,
    );

    // Holding a day previews it; Start in the sheet starts it.
    await tester.longPress(find.text('Push'));
    await pumpUntil(tester, find.text('Start Push'));
    expect(find.text('3 sets of 8-12 reps'), findsOneWidget);
    expect(find.text('Edit in Splits'), findsOneWidget);
    await tester.tap(find.text('Start Push'));
    await pumpUntil(tester, find.text('Finish'));
    final started = app.workout.state;
    expect(started.planTitle, 'Push');
    expect(started.splitTitle, 'PPL');
    expect(started.splitId, split.id);
    expect(started.splitDayIndex, 0);
    expect(started.gymName, 'Iron Temple');
    expect(started.plan.single.sets, hasLength(3));

    await app.workout.discardWorkout();
    await pumpUntil(tester, find.text('Start Pull'));

    // Pick another gym for next time, then tap a day: it starts at once.
    app.workout.rememberGym(home);
    await pumpUntil(tester, find.text('Home'));
    await tester.tap(find.text('Legs'));
    await pumpUntil(tester, find.text('Finish'));
    expect(app.workout.state.planTitle, 'Legs');
    expect(app.workout.state.splitDayIndex, 2);
    expect(app.workout.state.gymName, 'Home');
    expect(find.text('Add an exercise to start logging sets.'), findsOneWidget);
  });
}
