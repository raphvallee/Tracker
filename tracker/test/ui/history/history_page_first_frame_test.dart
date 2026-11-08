// One Isar-backed case per file: each *_test.dart runs in its own
// flutter_tester process with a fresh libisar native worker pool (see
// docs/TESTING_ISAR_CI.md).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/history/widgets/calendar/history_calendar.dart';
import 'package:tracker/ui/history/widgets/history_page.dart';

import '../../../testing/session_edit_helpers.dart';
import '../../../testing/test_helpers.dart';

void main() {
  setUpAll(initIsarCore);

  testWidgets(
    'History shows the calendar on its first frame and loads the list lazily',
    (tester) async {
      final now = DateTime.now();
      late TrackerRepository repo;
      await tester.runAsync(() async {
        final isar = await openTestIsar([
          GymSchema,
          WorkoutSessionSchema,
        ], name: 'history_page_first_frame');
        repo = TrackerRepository(isar);
        await repo.sessions.put(
          WorkoutSession(
            title: 'Today session',
            startTime: DateTime(now.year, now.month, now.day, 0, 1),
          ),
        );
        await repo.sessions.put(
          WorkoutSession(
            title: 'Older session',
            startTime: DateTime(now.year, now.month - 1, 15, 9),
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

      // Synchronous reads: no loading spinner, today's session is listed.
      expect(find.byType(FCircularProgress), findsNothing);
      expect(find.byType(HistoryCalendar), findsOneWidget);
      expect(find.text('Today session'), findsOneWidget);
      expect(find.text('Older session'), findsNothing);

      await tester.tap(find.text('List'));
      await tester.pump();
      expect(find.byType(HistoryCalendar), findsNothing);
      expect(find.textContaining('Today session'), findsOneWidget);
      expect(find.textContaining('Older session'), findsOneWidget);

      // Saves while the list is shown land through the change watcher.
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
        () async => find.textContaining('Saved later').evaluate().isNotEmpty,
      );

      await tester.tap(find.text('Calendar'));
      await tester.pump();
      expect(find.text('Saved later'), findsOneWidget);
      expect(find.text('Today session'), findsOneWidget);
    },
  );
}
