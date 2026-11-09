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
import 'package:tracker/ui/core/ui/swipe_to_delete.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/isar_app_helpers.dart';
import '../../../testing/test_helpers.dart';
import '../../../testing/workout_helpers.dart';

void main() {
  setUpAll(initIsarCore);
  setUp(() => HydratedBloc.storage = InMemoryStorage());

  testWidgets(
    'an exercise goes in two swipes; a chip swipe stays the chip\'s',
    (tester) async {
      useTallWindow(tester);
      late TrackerRepository repo;
      late int splitId;
      late int incline;
      await tester.runAsync(() async {
        final isar = await openTestIsar([
          ExerciseSchema,
          GymSchema,
          WorkoutSessionSchema,
          WorkoutSplitSchema,
        ], name: 'split_day_exercise_swipe');
        repo = TrackerRepository(isar);
        final bench = await repo.exercises.put(
          Exercise(
            title: 'Bench Press',
            primaryMuscle: [Muscle.chest],
            equipment: [Equipment.barbell],
          ),
        );
        incline = await repo.exercises.put(
          Exercise(
            title: 'Incline Press',
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
                  ExerciseItem(
                    exerciseId: incline,
                    order: 1,
                    sets: [PlannedSet(minReps: 10)],
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
          .onChange!(3);
      await pumpUntil(tester, find.text('Push'));
      await tester.tap(find.text('Push'));
      await pumpUntil(tester, find.text('Bench Press'));
      await pumpRounds(tester, 4);

      final name = find.text('Bench Press');
      final block = find.ancestor(
        of: name,
        matching: find.byType(SwipeToDelete),
      );
      final rest = tester.getTopLeft(name).dx;
      Future<void> swipe(Finder target, double dx) async {
        await tester.timedDrag(
          target,
          Offset(dx, 0),
          const Duration(milliseconds: 300),
        );
        await pumpRounds(tester, 4);
      }

      // A swipe on a set chip arms that chip; the exercise does not move.
      await swipe(labelled('Set 2, 8-12 reps'), -60);
      expect(find.byIcon(FLucideIcons.trash2), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
      expect(tester.getTopLeft(name).dx, rest);
      // The section title (the nav bar has an Exercises tab too).
      await tester.tap(find.text('Exercises').first);
      await pumpRounds(tester, 3);
      expect(find.byIcon(FLucideIcons.trash2), findsNothing);

      // From the grip, a drag reorders: it never opens the exercise.
      await swipe(find.byIcon(FLucideIcons.gripVertical).first, -200);
      expect(find.text('Delete'), findsNothing);
      expect(tester.getTopLeft(name).dx, rest);

      // One swipe, however far, only opens the exercise on Delete.
      await swipe(name, -600);
      expect(find.text('Delete'), findsOneWidget);
      expect(tester.getTopLeft(name).dx, rest - SwipeToDelete.actionWidth);
      expect(app.drafts.state.entries, isEmpty);
      // A tap on it closes it again.
      await tester.tap(block, warnIfMissed: false);
      await pumpRounds(tester, 4);
      expect(find.text('Delete'), findsNothing);
      expect(tester.getTopLeft(name).dx, rest);

      // Two swipes remove it; it stays restorable until the split is saved.
      await swipe(name, -300);
      await swipe(block, -500);
      await pumpUntil(tester, find.text('Restore'));
      expect(
        app.drafts.state.entries[splitId]!.draft.days.single.exercises.map(
          (exercise) => exercise.exerciseId,
        ),
        [incline],
      );
      expect(find.text('1 unsaved change'), findsOneWidget);
    },
  );
}
