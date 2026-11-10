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
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/models/workout_split.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/isar_app_helpers.dart';
import '../../../testing/test_helpers.dart';
import '../../../testing/workout_helpers.dart';

void main() {
  setUpAll(initIsarCore);
  setUp(() => HydratedBloc.storage = InMemoryStorage());

  testWidgets('the day due is open at home; a tap opens another day', (
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
      // Push was trained yesterday, for 45 minutes: Pull is due.
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await repo.sessions.put(
        WorkoutSession(
          title: 'PPL · Push',
          startTime: yesterday,
          endTime: yesterday.add(const Duration(minutes: 45)),
          splitId: split.id,
          splitDayIndex: 0,
          sets: [
            WorkoutSet(exerciseId: bench, weight: 77.5, reps: 10),
            WorkoutSet(exerciseId: bench, weight: 80, reps: 8, order: 1),
          ],
        ),
      );
    });

    final app = await pumpRealApp(tester, repo);
    await pumpUntil(tester, find.byType(FBottomNavigationBar));
    tester
        .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
        .onChange!(2);
    await pumpUntil(tester, find.text('Start Pull'));

    // The split's days in a row: the one up next is open, with its plan.
    expect(find.text('PPL'), findsOneWidget);
    expect(find.text('Up next'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget, reason: 'Push');
    expect(find.text('Barbell Row'), findsOneWidget);
    expect(find.text('1 × 10'), findsOneWidget, reason: 'the plan');
    expect(find.text('1 set'), findsOneWidget);
    expect(
      find.text('Not done yet'),
      findsNWidgets(2),
      reason: 'Pull, open, and Legs in the row',
    );
    expect(find.text('Iron Temple'), findsOneWidget, reason: 'home gym');

    // Tapping a day opens it in place, with what it did last time; Start
    // follows it and lands on the exercise list.
    await tester.tap(find.text('Push'));
    await pumpUntil(tester, find.text('Start Push'));
    expect(find.text('Last done yesterday, in 45 min'), findsOneWidget);
    expect(find.text('3 × 8-12'), findsOneWidget);
    expect(find.text('3 sets'), findsOneWidget);
    await pumpUntil(tester, find.text('Last 80 kg × 8'));
    expect(find.text('Up next'), findsOneWidget, reason: 'still Pull');
    await tester.tap(find.text('Start Push'));
    await pumpUntil(tester, find.text('Continue Bench Press'));
    await pumpUntil(tester, find.text('Set 1'));
    final started = app.workout.state;
    expect(started.planTitle, 'Push');
    expect(started.splitTitle, 'PPL');
    expect(started.splitId, split.id);
    expect(started.splitDayIndex, 0);
    expect(started.gymName, 'Iron Temple');
    expect(started.plan.single.sets, hasLength(3));

    // On the exercise, the set opens on last time's numbers: nothing to
    // compare until one of them moves.
    await tester.tap(find.text('Continue Bench Press'));
    await pumpUntil(tester, find.text('last 77.5'));
    expect(find.textContaining('than last time'), findsNothing);
    await tester.tap(labelled('Increase reps'));
    await tester.pump();
    expect(find.text('1 rep more than last time'), findsOneWidget);

    await app.workout.discardWorkout();
    await pumpUntil(tester, find.text('Start Pull'));

    // Pick another gym for the next workout, then open a day with nothing
    // planned and start it: it starts there.
    app.workout.pickNextGym(home);
    await pumpUntil(tester, find.text('Home'));
    await tester.tap(find.text('Legs'));
    await pumpUntil(tester, find.text('Start Legs'));
    expect(find.text('No exercises yet. Add some in Splits.'), findsOneWidget);
    await tester.tap(find.text('Start Legs'));
    await pumpUntil(tester, find.text('Finish'));
    expect(app.workout.state.planTitle, 'Legs');
    expect(app.workout.state.splitDayIndex, 2);
    expect(app.workout.state.gymName, 'Home');
    expect(find.text('Add an exercise to start logging sets.'), findsOneWidget);

    // The pick lasted one workout: the next one is back at home.
    await app.workout.discardWorkout();
    await pumpUntil(tester, find.text('Start Pull'));
    expect(find.text('Iron Temple'), findsOneWidget);
  });
}
