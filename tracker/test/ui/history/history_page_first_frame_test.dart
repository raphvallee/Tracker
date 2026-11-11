// One Isar-backed case per file: each *_test.dart runs in its own
// flutter_tester process with a fresh libisar native worker pool (see
// docs/TESTING_ISAR_CI.md).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/muscle.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/ui/core/ui/relative_dates.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/history/widgets/history_page.dart';

import '../../../testing/session_edit_helpers.dart';
import '../../../testing/test_helpers.dart';

void main() {
  setUpAll(initIsarCore);

  testWidgets(
    'History lists every workout on its first frame, by month, newest first',
    (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 0, 1);
      final lastMonth = DateTime(now.year, now.month - 1, 15, 9);
      late TrackerRepository repo;
      await tester.runAsync(() async {
        final isar = await openTestIsar([
          ExerciseSchema,
          GymSchema,
          WorkoutSessionSchema,
        ], name: 'history_page_first_frame');
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
        final press = await exercise('Overhead Press');
        final dips = await exercise('Dips');
        await repo.sessions.put(
          WorkoutSession(
            title: 'Today session',
            startTime: today,
            endTime: today.add(const Duration(hours: 1, minutes: 5)),
            sets: [
              WorkoutSet(
                exerciseId: bench,
                weight: 40,
                reps: 10,
                type: SetType.warmup,
              ),
              WorkoutSet(exerciseId: bench, weight: 80, reps: 8, order: 1),
              WorkoutSet(exerciseId: press, weight: 50, reps: 8, order: 2),
              WorkoutSet(exerciseId: dips, weight: 0, reps: 12, order: 3),
            ],
          ),
        );
        await repo.sessions.put(
          WorkoutSession(
            title: 'Older session',
            startTime: lastMonth,
            endTime: lastMonth.add(const Duration(minutes: 34)),
            sets: [WorkoutSet(exerciseId: press, weight: 50, reps: 8)],
          ),
        );
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

      // Synchronous reads: no loading spinner, every workout is listed.
      expect(find.byType(FCircularProgress), findsNothing);
      expect(find.text('Today session'), findsOneWidget);
      expect(find.text('Older session'), findsOneWidget);
      expect(find.text(monthLabel(now.year, now.month)), findsOneWidget);
      expect(
        find.text(monthLabel(lastMonth.year, lastMonth.month)),
        findsOneWidget,
      );
      expect(find.text('1 workout'), findsNWidgets(2));
      // The date gutter, what was done, how long and how many sets.
      expect(find.text(weekdayLabel(today)), findsOneWidget);
      expect(
        find.text('Bench Press, Overhead Press and 1 more'),
        findsOneWidget,
      );
      expect(find.text('Overhead Press'), findsOneWidget);
      expect(find.text('1 h 5 min'), findsOneWidget);
      expect(find.text('3 sets'), findsOneWidget);
      expect(find.text('34 min'), findsOneWidget);
      expect(find.text('1 set'), findsOneWidget);
      expect(fButtonByTooltip('Calendar'), findsOneWidget);

      // Saves while History is shown land through the change watcher, at
      // the top of their month.
      await tester.runAsync(
        () => repo.sessions.put(
          WorkoutSession(
            title: 'Saved later',
            startTime: DateTime(now.year, now.month, now.day, 0, 2),
          ),
        ),
      );
      await waitForRealIo(
        tester,
        () async => find.text('Saved later').evaluate().isNotEmpty,
      );
      expect(find.text('2 workouts'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Saved later')).dy,
        lessThan(tester.getTopLeft(find.text('Today session')).dy),
      );

      // A tap opens the past workout.
      await tester.tap(find.text('Today session'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('1 set, 1 warm-up'), findsOneWidget);
    },
  );
}
