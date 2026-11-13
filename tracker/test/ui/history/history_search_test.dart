// One Isar-backed case per file: each *_test.dart runs in its own
// flutter_tester process with a fresh libisar native worker pool (see
// docs/TESTING_ISAR_CI.md).

import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/muscle.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/history/widgets/history_page.dart';

import '../../../testing/test_helpers.dart';

void main() {
  setUpAll(initIsarCore);

  testWidgets(
    'History search forgives typos, filters in a sheet and closes back',
    (tester) async {
      final now = DateTime.now();
      final day = DateTime(now.year, now.month, now.day, 0, 1);
      late TrackerRepository repo;
      await tester.runAsync(() async {
        final isar = await openTestIsar([
          ExerciseSchema,
          GymSchema,
          WorkoutSessionSchema,
          WorkoutSplitSchema,
        ], name: 'history_search');
        repo = TrackerRepository(isar);
        Future<int> exercise(String title) => repo.exercises.put(
          Exercise(
            title: title,
            primaryMuscle: [Muscle.chest],
            equipment: [Equipment.barbell],
            movementPattern: MovementPattern.push,
          ),
        );
        final bench = await exercise('Bench Press');
        final squat = await exercise('Squat');
        final split = await repo.splits.put(
          WorkoutSplit(
            title: 'Push Pull Legs',
            splitDays: [
              WorkoutSplitDay(title: 'Push'),
              WorkoutSplitDay(title: 'Pull'),
              WorkoutSplitDay(title: 'Legs'),
            ],
          ),
        );
        Future<void> session(
          String title,
          int daysAgo,
          int exercise,
          int dayIndex,
          int minutes,
        ) {
          final start = day.subtract(Duration(days: daysAgo));
          return repo.sessions
              .put(
                WorkoutSession(
                  title: title,
                  startTime: start,
                  endTime: start.add(Duration(minutes: minutes)),
                  splitId: split,
                  splitDayIndex: dayIndex,
                  sets: [WorkoutSet(exerciseId: exercise, weight: 80, reps: 8)],
                ),
              )
              .then((_) {});
        }

        await session('Push', 0, bench, 0, 70);
        await session('Legs', 1, squat, 2, 40);
        await session('Legs again', 3, squat, 2, 90);
      });

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              FTheme(data: FTheme.neutral.light.touch, child: child!),
          home: RepositoryScope(
            repository: repo,
            child: const Scaffold(body: HistoryPage()),
          ),
        ),
      );

      // Search is behind a button: no field until it is tapped.
      expect(find.byType(FTextField), findsNothing);
      await tester.tap(fButtonByTooltip('Search'));
      await tester.pumpAndSettle();
      expect(find.byType(FTextField), findsOneWidget);

      // A letter swapped still finds Squat, and says what it read.
      await tester.enterText(find.byType(EditableText), 'sqaut');
      await tester.pumpAndSettle();
      expect(find.text('Legs'), findsOneWidget);
      expect(find.text('Legs again'), findsOneWidget);
      expect(find.text('Push'), findsNothing);
      expect(
        find.textContaining('2 workouts matching Squat', findRichText: true),
        findsOneWidget,
      );

      // Filters narrow it further, counted before they apply.
      await tester.tap(find.bySemanticsLabel('Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 h 30 min or more'));
      await tester.pumpAndSettle();
      expect(find.text('Show 1 workout'), findsOneWidget);
      await tester.tap(find.text('Show 1 workout'));
      await tester.pumpAndSettle();
      expect(find.text('Legs again'), findsOneWidget);
      expect(find.text('Legs'), findsNothing);
      expect(
        find.textContaining('lasting 1 h 30 min or more', findRichText: true),
        findsOneWidget,
      );

      // Nothing found: a way back.
      await tester.enterText(find.byType(EditableText), 'deadlift');
      await tester.pumpAndSettle();
      expect(find.text('No workouts match'), findsOneWidget);
      await tester.tap(find.text('Clear search and filters'));
      await tester.pumpAndSettle();
      expect(find.text('Push'), findsOneWidget);

      // Closing search puts History back as it was.
      await tester.tap(fButtonByTooltip('Close search'));
      await tester.pumpAndSettle();
      expect(find.byType(FTextField), findsNothing);
      expect(find.text('Legs again'), findsOneWidget);
      expect(fButtonByTooltip('Calendar'), findsOneWidget);
    },
  );
}
