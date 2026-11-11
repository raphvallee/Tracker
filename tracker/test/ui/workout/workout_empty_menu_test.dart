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
import 'package:tracker/ui/core/ui/sheet_surface.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/isar_app_helpers.dart';
import '../../../testing/test_helpers.dart';
import '../../../testing/workout_helpers.dart';

void main() {
  setUpAll(initIsarCore);
  setUp(() => HydratedBloc.storage = InMemoryStorage());

  testWidgets('the split sheet ends with Empty workout, which starts a '
      'workout without a plan', (tester) async {
    useTallWindow(tester);
    late TrackerRepository repo;
    await tester.runAsync(() async {
      final isar = await openTestIsar([
        ExerciseSchema,
        GymSchema,
        WorkoutSessionSchema,
        WorkoutSplitSchema,
      ], name: 'workout_empty_menu');
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

    // The day's page offers no empty workout of its own: the split's name
    // opens the sheet that does, even with one split saved.
    expect(find.text('Empty workout'), findsNothing);
    await tester.tap(labelled('Split: PPL. Choose what to train from'));
    await pumpUntil(tester, find.text('Train from'));
    await tester.pump(const Duration(milliseconds: 500));

    // Last of all, under the split.
    final sheet = find.byType(SheetSurface);
    final splitRow = tester.getTopLeft(
      find.descendant(of: sheet, matching: find.text('PPL')),
    );
    final emptyRow = tester.getTopLeft(
      find.descendant(of: sheet, matching: find.text('Empty workout')),
    );
    expect(emptyRow.dy, greaterThan(splitRow.dy));

    await tester.tap(find.text('Empty workout'));
    await pumpUntil(tester, find.text('Free workout'));
    expect(app.workout.state.isInProgress, isTrue);
    expect(app.workout.state.planTitle, isNull);
    expect(app.workout.state.splitId, isNull);
    expect(app.workout.state.gymName, 'Iron Temple');
  });
}
