// One Isar-backed case per file: each *_test.dart runs in its own
// flutter_tester process with a fresh libisar native worker pool (see
// docs/TESTING_ISAR_CI.md).

import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/ui/core/ui/relative_dates.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/history/widgets/calendar/history_calendar.dart';
import 'package:tracker/ui/history/widgets/history_page.dart';

import '../../../testing/test_helpers.dart';

void main() {
  setUpAll(initIsarCore);

  testWidgets(
    'a workout day picked on the calendar scrolls the list to its workout',
    (tester) async {
      final now = DateTime.now();
      DateTime dayAgo(int days) =>
          DateTime(now.year, now.month, now.day - days, 18);
      late TrackerRepository repo;
      await tester.runAsync(() async {
        final isar = await openTestIsar([
          ExerciseSchema,
          GymSchema,
          WorkoutSessionSchema,
        ], name: 'history_calendar_jump');
        repo = TrackerRepository(isar);
        for (var i = 0; i < 60; i++) {
          await repo.sessions.put(
            WorkoutSession(
              title: 'Workout $i',
              startTime: dayAgo(i),
              endTime: dayAgo(i).add(const Duration(minutes: 50)),
              sets: [WorkoutSet(exerciseId: 1, weight: 60, reps: 8)],
            ),
          );
        }
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
      Future<void> settle() async {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }

      expect(find.text('Workout 0'), findsOneWidget);
      const target = 45;
      expect(find.text('Workout $target'), findsNothing);

      await tester.tap(fButtonByTooltip('Calendar'));
      await settle();
      expect(find.byType(HistoryCalendar), findsOneWidget);
      expect(find.text('${monthName(now.month)} ${now.year}'), findsOneWidget);

      final day = dayAgo(target);
      final monthsBack =
          (now.year * 12 + now.month) - (day.year * 12 + day.month);
      for (var i = 0; i < monthsBack; i++) {
        await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
        await tester.pumpAndSettle();
      }
      expect(find.text('${monthName(day.month)} ${day.year}'), findsOneWidget);

      await tester.tap(
        find.bySemanticsLabel('Workout on ${shortDateLabel(day)}'),
      );
      await settle();

      // The sheet is gone and the day's workout sits at the top of the list,
      // under the app bar.
      expect(find.byType(HistoryCalendar), findsNothing);
      final top = tester.getTopLeft(find.text('Workout $target')).dy;
      expect(top, greaterThan(40));
      expect(top, lessThan(200));
      // The one before it in the list (a day newer) is scrolled away above.
      final newer = find.text('Workout ${target - 1}');
      if (newer.evaluate().isNotEmpty) {
        expect(tester.getTopLeft(newer).dy, lessThan(top));
      }
      // Let the mark on the row fade before the test ends.
      await tester.pump(const Duration(seconds: 2));
    },
  );
}
