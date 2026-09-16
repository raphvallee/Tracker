// History presentation regressions use fake repositories, not native Isar.
// Calendar math is covered separately in calendar_test.dart.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:tracker/data/repositories/gym_repository.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/data/repositories/workout_session_repository.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/history/view_models/calendar_view_model.dart';
import 'package:tracker/ui/history/widgets/calendar/history_calendar.dart';
import 'package:tracker/ui/history/widgets/history_page.dart';
import 'package:tracker/ui/history/widgets/session_detail_page.dart';

import '../../../testing/test_helpers.dart';
import 'counting_sessions.dart';

void main() {
  testWidgets(
    'HistoryPage retains lazy calendar caches across real tab toggles',
    (tester) async {
      final repository = _HistoryRepository();
      addTearDown(repository.sessions.controller.close);
      await tester.pumpWidget(_historyApp(repository));
      final sessions = CountingSessions(
        List.generate(
          8,
          (i) => WorkoutSession(
            title: 'Workout $i',
            startTime: DateTime(2026, 3, i + 1),
          ),
        ),
      );
      repository.sessions.controller.add(sessions);
      await tester.pumpAndSettle();
      expect(find.byType(HistoryCalendar), findsNothing);
      // List renders eagerly today; count calendar work independently of it.
      final listReads = sessions.reads;
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();
      final firstState = tester.state(find.byType(HistoryCalendar));
      final model = tester
          .widget<HistoryCalendar>(find.byType(HistoryCalendar))
          .model!;
      final index = model.dateIndex;
      expect(sessions.reads - listReads, sessions.length);
      final calendarReads = sessions.reads;
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('12'));
      await tester.pumpAndSettle();
      final day = model.selectedDay!;
      final grid = model.grid;
      final days = model.daysWithWorkouts;
      expect(sessions.reads, calendarReads);
      expect(find.text('Workouts · ${_date(day)}'), findsOneWidget);

      for (var round = 0; round < 3; round++) {
        await tester.tap(find.text('List'));
        await tester.pumpAndSettle();
        expect(find.byType(HistoryCalendar), findsNothing);
        final beforeRemount = sessions.reads;
        await tester.tap(find.text('Calendar'));
        await tester.pumpAndSettle();
        final calendar = tester.widget<HistoryCalendar>(
          find.byType(HistoryCalendar),
        );
        expect(
          tester.state(find.byType(HistoryCalendar)),
          isNot(same(firstState)),
        );
        expect(calendar.model, same(model));
        expect(model.dateIndex, same(index));
        expect(model.grid, same(grid));
        expect(model.daysWithWorkouts, same(days));
        expect(model.selectedDay, day);
        expect(sessions.reads, beforeRemount);
        expect(find.text('Workouts · ${_date(day)}'), findsOneWidget);
      }
      expect(repository.sessions.watches, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'HistoryPage preserves selection through error, empty and loading',
    (tester) async {
      final repository = _HistoryRepository();
      final replacement = _HistoryRepository();
      addTearDown(repository.sessions.controller.close);
      addTearDown(replacement.sessions.controller.close);
      await tester.pumpWidget(_historyApp(repository));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final sessions = [
        WorkoutSession(title: 'Original', startTime: DateTime(2026, 3, 12)),
      ];
      repository.sessions.controller.add(sessions);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('12'));
      await tester.pumpAndSettle();
      final model = tester
          .widget<HistoryCalendar>(find.byType(HistoryCalendar))
          .model!;
      final day = model.selectedDay!;
      final grid = model.grid;
      final index = model.dateIndex;

      void expectRetained() {
        expect(
          tester.widget<HistoryCalendar>(find.byType(HistoryCalendar)).model,
          same(model),
        );
        expect(model.selectedDay, day);
        expect(model.grid, same(grid));
        expect(find.text('Workouts · ${_date(day)}'), findsOneWidget);
      }

      repository.sessions.controller.addError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.text('Could not load workout history.'), findsOneWidget);
      expect(find.byType(HistoryCalendar), findsNothing);
      repository.sessions.controller.add(sessions);
      await tester.pumpAndSettle();
      expectRetained();
      expect(model.dateIndex, same(index));

      repository.sessions.controller.add(const []);
      await tester.pumpAndSettle();
      expect(find.text('No workouts logged yet'), findsOneWidget);
      expect(find.byType(HistoryCalendar), findsNothing);
      expect(model.sessionsOn(DateTime(2026, 3, 12)), isEmpty);
      repository.sessions.controller.add(sessions);
      await tester.pumpAndSettle();
      expectRetained();

      // Replacing the scope creates a genuine StreamBuilder waiting transition.
      await tester.pumpWidget(_historyApp(replacement));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(HistoryCalendar), findsNothing);
      expect(model.sessionsOn(DateTime(2026, 3, 12)), isEmpty);
      expect(model.selectedDay, day);
      expect(repository.sessions.controller.hasListener, isFalse);
      replacement.sessions.controller.add([
        WorkoutSession(title: 'Replacement', startTime: day),
      ]);
      await tester.pumpAndSettle();
      expectRetained();
      expect(find.text('Replacement'), findsOneWidget);
      expect(model.dateIndex, isNot(same(index)));
      expect(repository.sessions.watches, 1);
      expect(replacement.sessions.watches, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(replacement.sessions.controller.hasListener, isFalse);
    },
  );

  testWidgets(
    'calendar can switch between external and internal model ownership',
    (tester) async {
      final first = CalendarViewModel(initialDate: DateTime(2026, 3, 12));
      final second = CalendarViewModel(initialDate: DateTime(2026, 4, 14));
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      final sessions = [WorkoutSession(startTime: DateTime(2026, 3, 12))];
      Future<void> show(CalendarViewModel? model) async {
        await tester.pumpWidget(
          _themed(
            Scaffold(
              body: HistoryCalendar(
                sessions: sessions,
                gymNames: const {},
                model: model,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      await show(first);
      final state = tester.state(find.byType(HistoryCalendar));
      expect(find.text('March 2026'), findsOneWidget);
      await show(null); // Used to dereference a null owned model.
      expect(tester.state(find.byType(HistoryCalendar)), same(state));
      first.selectDay(
        DateTime(2026, 3, 13),
      ); // External model was not disposed.
      await show(second);
      expect(find.text('April 2026'), findsOneWidget);
      await show(first);
      expect(find.text('Workouts · 2026-03-13'), findsOneWidget);
      second.selectDay(DateTime(2026, 4, 15));
      await show(null);
      await tester.pumpWidget(const SizedBox.shrink());
      first.selectDay(DateTime(2026, 3, 14));
      second.selectDay(DateTime(2026, 4, 16));
    },
  );

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

String _date(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

Widget _themed(Widget child) => MaterialApp(
  builder: (context, child) =>
      FTheme(data: FTheme.neutral.light.desktop, child: child!),
  home: child,
);

Widget _historyApp(_HistoryRepository repository) => _themed(
  RepositoryScope(
    repository: repository,
    child: const Scaffold(body: HistoryPage()),
  ),
);

class _HistoryRepository extends Fake implements TrackerRepository {
  @override
  final _SessionsRepository sessions = _SessionsRepository();
  @override
  final gyms = _GymsRepository();
}

class _SessionsRepository extends Fake implements WorkoutSessionRepository {
  final controller = StreamController<List<WorkoutSession>>();
  int watches = 0;

  @override
  Stream<List<WorkoutSession>> watchAll() {
    watches++;
    return controller.stream;
  }
}

class _GymsRepository extends Fake implements GymRepository {
  @override
  Future<List<Gym>> getAll() async => const [];
}
