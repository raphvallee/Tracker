// One Isar-backed case per file: each *_test.dart runs in its own
// flutter_tester process with a fresh libisar native worker pool (see
// docs/TESTING_ISAR_CI.md).

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/muscle.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/ui/core/ui/swipe_to_delete.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/isar_app_helpers.dart';
import '../../../testing/test_helpers.dart';
import '../../../testing/workout_helpers.dart';

void main() {
  setUpAll(initIsarCore);
  setUp(() => HydratedBloc.storage = InMemoryStorage());

  testWidgets('a day row peeks on hold or hover, and goes in two swipes', (
    tester,
  ) async {
    useTallWindow(tester);
    late TrackerRepository repo;
    late int splitId;
    await tester.runAsync(() async {
      final isar = await openTestIsar([
        ExerciseSchema,
        GymSchema,
        WorkoutSessionSchema,
        WorkoutSplitSchema,
      ], name: 'split_day_row');
      repo = TrackerRepository(isar);
      final bench = await repo.exercises.put(
        Exercise(
          title: 'Bench Press',
          primaryMuscle: [Muscle.chest],
          equipment: [Equipment.barbell],
        ),
      );
      splitId = await repo.splits.put(
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
            WorkoutSplitDay(title: 'Pull'),
          ],
        ),
      );
      await repo.sessions.put(
        WorkoutSession(
          title: 'PPL · Push',
          startTime: DateTime.now().subtract(const Duration(days: 1)),
          splitId: splitId,
          splitDayIndex: 0,
        ),
      );
    });

    final app = await pumpRealApp(tester, repo);
    await pumpUntil(tester, find.byType(FBottomNavigationBar));
    tester
        .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
        .onChange!(3);
    await pumpUntil(tester, find.text('Pull'));

    // Holding a day peeks at it; any tap closes the peek.
    await tester.longPress(find.text('Push'));
    await pumpRounds(tester, 3);
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('3 sets of 8-12 reps'), findsOneWidget);
    expect(find.textContaining('last done yesterday'), findsOneWidget);
    expect(find.text('Day name'), findsNothing, reason: 'not opened');
    await tester.tapAt(const Offset(400, 40));
    await pumpRounds(tester, 3);
    expect(find.text('Bench Press'), findsNothing);

    // A mouse resting on a day peeks too, until it leaves.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(400, 40));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('Pull')));
    await pumpRounds(tester, 6);
    const empty = 'No exercises yet. Tap the day to add some.';
    expect(find.text(empty), findsOneWidget);
    await mouse.moveTo(const Offset(400, 40));
    await pumpRounds(tester, 3);
    expect(find.text(empty), findsNothing);

    // One swipe only opens the day on Delete; the second deletes it.
    // From the row's middle: open, the row has slid its name off the left.
    final row = find.ancestor(
      of: find.text('Pull'),
      matching: find.byType(SwipeToDelete),
    );
    Future<void> swipe() async {
      await tester.timedDrag(
        row,
        const Offset(-500, 0),
        const Duration(milliseconds: 300),
      );
      await pumpRounds(tester, 4);
    }

    await swipe();
    expect(find.text('Delete'), findsOneWidget);
    expect(app.drafts.state.entries, isEmpty);
    await swipe();
    await pumpUntil(tester, find.text('Restore'));
    expect(app.drafts.state.entries[splitId]!.draft.days.map((d) => d.title), [
      'Push',
    ]);
  });
}
