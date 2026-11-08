import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/ui/history/widgets/calendar/history_calendar.dart';
import 'package:tracker/ui/history/widgets/session_detail_page.dart';

import '../../../testing/test_helpers.dart';

void main() {
  testWidgets('calendar keeps a bounded internal day list', (tester) async {
    final sessions = List.generate(
      8,
      (index) =>
          WorkoutSession(title: 'Workout $index', startTime: DateTime.now()),
    );

    await pumpAppPage(
      tester,
      Scaffold(
        body: HistoryCalendar(sessions: sessions, gymNames: const {}),
      ),
    );

    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('Workout 0'), findsOneWidget);
  });

  group('SessionDetailPage UI', () {
    testWidgets('renders header, stats and every set with warmup marker', (
      tester,
    ) async {
      final session = WorkoutSession(
        title: 'Home workout',
        startTime: DateTime(2026, 1, 1, 9),
        endTime: DateTime(2026, 1, 1, 10),
        gymId: 3,
        sets: [
          WorkoutSet(
            exerciseId: 1,
            weight: 80,
            reps: 5,
            type: SetType.working,
            order: 0,
          ),
          WorkoutSet(
            exerciseId: 1,
            weight: 60,
            reps: 8,
            type: SetType.warmup,
            order: 1,
          ),
        ],
      );

      await pumpAppPage(
        tester,
        SessionDetailPage(session: session, gymName: 'Home'),
      );

      expect(find.text('Home workout'), findsOneWidget);
      expect(find.text('Home · 1h 0m'), findsOneWidget);
      expect(find.text('80 kg × 5'), findsOneWidget);
      expect(find.text('60 kg × 8'), findsOneWidget);
      expect(find.text('W'), findsOneWidget);
      expect(find.text('S'), findsOneWidget);
    });

    testWidgets('shows a working volume that excludes warmup sets', (
      tester,
    ) async {
      await pumpAppPage(
        tester,
        SessionDetailPage(
          session: WorkoutSession(
            title: 'Push',
            startTime: DateTime(2026, 1, 2, 9),
            endTime: DateTime(2026, 1, 2, 10),
            sets: [
              WorkoutSet(
                exerciseId: 1,
                weight: 100,
                reps: 5,
                type: SetType.working,
                order: 0,
              ),
              WorkoutSet(
                exerciseId: 1,
                weight: 60,
                reps: 8,
                type: SetType.warmup,
                order: 1,
              ),
            ],
          ),
          gymName: null,
        ),
      );

      expect(find.text('500 kg'), findsOneWidget);
    });
  });
}
