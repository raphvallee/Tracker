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
import 'package:tracker/domain/models/workout_session_summary.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/routing/tab_navigation.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/history/view_models/calendar_view_model.dart';
import 'package:tracker/ui/history/widgets/calendar/history_calendar.dart';
import 'package:tracker/ui/history/widgets/history_page.dart';
import 'package:tracker/ui/history/widgets/session_detail_page.dart';

import '../../../testing/test_helpers.dart';
import 'counting_sessions.dart';

void main() {
  testWidgets('calendar clock rebuilds metrics only while visible', (
    tester,
  ) async {
    var now = DateTime(2026, 3, 4, 23, 59, 59);
    final model = CalendarViewModel(now: () => now);
    final sessions = [WorkoutSession(startTime: DateTime(2026, 3, 3))];
    Future<void> show(bool active) => tester.pumpWidget(
      _themed(
        TabVisibilityScope(
          index: 1,
          isActive: active,
          child: Scaffold(
            body: HistoryCalendar(
              sessions: sessions,
              gymNames: const {},
              model: model,
            ),
          ),
        ),
      ),
    );
    await show(true);
    final index = model.dateIndex;
    now = DateTime(2026, 3, 5);
    await tester.pump(const Duration(seconds: 1));
    expect(model.streak, 0);
    final metric = find
        .ancestor(of: find.text('day streak'), matching: find.byType(Row))
        .first;
    expect(
      find.descendant(of: metric, matching: find.text('0')),
      findsOneWidget,
    );
    expect(model.dateIndex, same(index));
    await show(false);
    now = DateTime(2026, 3, 7);
    await tester.pump(const Duration(days: 2));
    expect(model.today, DateTime(2026, 3, 5));
    await show(true);
    expect(model.today, now);
    expect(model.dateIndex, same(index));
    await tester.pumpWidget(const SizedBox.shrink());
    now = DateTime(2026, 3, 8);
    await tester.pump(const Duration(days: 1));
    expect(model.today, DateTime(2026, 3, 7));
    model.dispose();
  });

  testWidgets(
    'HistoryPage scopes subscriptions and retains compact navigation',
    (tester) async {
      final repository = _HistoryRepository();
      addTearDown(repository.sessions.close);
      await tester.pumpWidget(_historyApp(repository));
      final sessions = CountingSessions([
        WorkoutSession(title: 'List only', startTime: DateTime(2026, 3, 12)),
      ]);
      repository.sessions.controller.add(sessions);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Calendar'));
      await tester.pump();
      expect(repository.sessions.controller.hasListener, isFalse);
      final reads = sessions.reads;
      repository.sessions.dates.add([DateTime(2026, 3, 12)]);
      repository.sessions.days.last.add(const []);
      await tester.pumpAndSettle();
      final model = tester
          .widget<HistoryCalendar>(find.byType(HistoryCalendar))
          .model!;
      expect(
        tester.widget<HistoryCalendar>(find.byType(HistoryCalendar)).sessions,
        isNull,
      );
      final requests = repository.sessions.days.length;
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      expect(repository.sessions.days.length, requests);
      expect(repository.sessions.days.last.hasListener, isFalse);
      await tester.tap(find.text('12'));
      await tester.pump();
      repository.sessions.days.last.add(const []);
      await tester.pumpAndSettle();
      final day = model.selectedDay;
      final grid = model.grid;
      expect(sessions.reads, reads);
      await tester.tap(find.text('List'));
      await tester.pump();
      expect(repository.sessions.dates.hasListener, isFalse);
      expect(repository.sessions.days.last.hasListener, isFalse);
      repository.sessions.controller.add(const []);
      await tester.pumpAndSettle();
      expect(find.text('No workouts logged yet'), findsOneWidget);
      await tester.tap(find.text('Calendar'));
      await tester.pump();
      repository.sessions.dates.add([DateTime(2026, 3, 12)]);
      repository.sessions.days.last.add(const []);
      await tester.pumpAndSettle();
      expect(model.selectedDay, day);
      expect(model.grid, same(grid));
      expect(repository.sessions.watches, 2);
      expect(repository.sessions.dateWatches, 2);
      expect(sessions.reads, reads);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'calendar errors/retry and repository replacement preserve navigation',
    (tester) async {
      final repository = _HistoryRepository();
      final replacement = _HistoryRepository();
      addTearDown(repository.sessions.close);
      addTearDown(replacement.sessions.close);
      await tester.pumpWidget(_historyApp(repository));
      await tester.tap(find.text('Calendar'));
      await tester.pump();
      repository.sessions.dates.add([DateTime(2026, 3, 12)]);
      repository.sessions.days.last.add(const []);
      await tester.pumpAndSettle();
      final model = tester
          .widget<HistoryCalendar>(find.byType(HistoryCalendar))
          .model!;
      final day = model.selectedDay!;
      repository.sessions.dates.addError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not refresh calendar'), findsOneWidget);
      expect(model.selectedDay, day);
      await tester.tap(find.text('Retry calendar'));
      await tester.pump();
      repository.sessions.dates.add(const []);
      await tester.pumpAndSettle();
      expect(model.dateIndex.workoutDays, isEmpty);
      await tester.pumpWidget(_historyApp(replacement));
      await tester.pump();
      expect(repository.sessions.dates.hasListener, isFalse);
      expect(repository.sessions.days.last.hasListener, isFalse);
      expect(model.selectedDay, day);
      replacement.sessions.dates.add([day]);
      replacement.sessions.days.last.add([
        WorkoutSessionSummary(
          id: 42,
          title: 'Replacement',
          startTime: day,
          setCount: 2,
          gymId: null,
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Replacement'), findsOneWidget);
      expect(replacement.sessions.watches, 0);
      await tester.pumpWidget(const SizedBox.shrink());
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
  final controller = StreamController<List<WorkoutSession>>.broadcast();
  final dates = StreamController<List<DateTime>>.broadcast();
  final days = <StreamController<List<WorkoutSessionSummary>>>[];
  int dateWatches = 0;

  Future<void> close() async {
    await controller.close();
    await dates.close();
    for (final day in days) {
      await day.close();
    }
  }

  @override
  Stream<List<DateTime>> watchStartTimes() {
    dateWatches++;
    return dates.stream;
  }

  @override
  Stream<List<WorkoutSessionSummary>> watchSummariesForDate(DateTime day) {
    final controller =
        StreamController<List<WorkoutSessionSummary>>.broadcast();
    days.add(controller);
    return controller.stream;
  }

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
