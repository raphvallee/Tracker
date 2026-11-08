// History integration tests (lib/pages/history/). The SessionDetailPage widget:
// it declares no dependency on repository data (exercise names degrade to ids)
// and the sets/gym/duration come straight from the session passed in. The
// calendar/streak math it can render is unit-tested separately:
// test/unit/calendar_test.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/ui/history/widgets/session_detail_page.dart';

import '../../../testing/test_helpers.dart';

void main() {
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

      expect(find.text('Home workout'), findsOneWidget); // app bar title
      expect(
        find.text('Home · 1h 0m'),
        findsOneWidget,
      ); // gym + duration in header
      expect(find.text('80 kg × 5'), findsOneWidget);
      expect(find.text('60 kg × 8'), findsOneWidget);
      expect(find.text('W'), findsOneWidget); // warmup marker
      expect(find.text('S'), findsOneWidget); // working marker
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

      // 100×5 = 500 kg working volume; the 60×8 warmup is excluded.
      expect(find.text('500 kg'), findsOneWidget);
    });
  });
}
