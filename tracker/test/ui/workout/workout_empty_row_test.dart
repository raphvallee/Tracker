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
import 'package:tracker/ui/core/ui/custom_app_bar.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/isar_app_helpers.dart';
import '../../../testing/test_helpers.dart';
import '../../../testing/workout_helpers.dart';

void main() {
  setUpAll(initIsarCore);
  setUp(() => HydratedBloc.storage = InMemoryStorage());

  testWidgets('a short plan shows the Empty workout row, which starts a '
      'workout without a plan', (tester) async {
    useTallWindow(tester);
    late TrackerRepository repo;
    await tester.runAsync(() async {
      final isar = await openTestIsar([
        ExerciseSchema,
        GymSchema,
        WorkoutSessionSchema,
        WorkoutSplitSchema,
      ], name: 'workout_empty_row');
      repo = TrackerRepository(isar);
      final bench = await repo.exercises.put(
        Exercise(
          title: 'Bench Press',
          primaryMuscle: [Muscle.chest],
          equipment: [Equipment.barbell],
        ),
      );
      await repo.gyms.put(Gym(name: 'Iron Temple', isPrimary: true, order: 0));
      await repo.splits.put(
        WorkoutSplit(
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
          ],
        ),
      );
    });

    final app = await pumpRealApp(tester, repo);
    await pumpUntil(tester, find.byType(FBottomNavigationBar));
    tester
        .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
        .onChange!(2);
    await pumpUntil(tester, find.text('Start Push'));
    await pumpRounds(tester);

    // The row sits under the plan, in full view: the header has no copy of
    // it, so there is one Empty workout to find, hit and read.
    expect(find.text('Pick exercises as you go'), findsOneWidget);
    expect(find.text('Empty workout'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CustomAppBar),
        matching: find.text('Empty workout'),
      ),
      findsNothing,
    );
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Empty workout'), findsNothing);
    semantics.dispose();

    await tester.tap(find.text('Empty workout'));
    await pumpUntil(tester, find.text('Free workout'));
    expect(app.workout.state.isInProgress, isTrue);
    expect(app.workout.state.planTitle, isNull);
    expect(app.workout.state.splitId, isNull);
    expect(app.workout.state.gymName, 'Iron Temple');
  });
}
