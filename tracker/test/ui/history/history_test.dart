// History presentation regressions use fake repositories, not native Isar.
// Calendar math is covered separately in calendar_test.dart.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:tracker/data/repositories/gym_repository.dart';
import 'package:tracker/data/repositories/exercise_repository.dart';
import 'package:tracker/domain/models/exercise.dart';
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

  testWidgets('standalone calendar uses one lazy viewport', (tester) async {
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

    expect(find.byType(ListView), findsNothing);
    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.byType(Scrollable), findsOneWidget);
    expect(find.byType(SliverList), findsOneWidget);
    expect(find.text('Workout 0'), findsOneWidget);
  });

  for (final size in [
    const Size(320, 568),
    const Size(800, 600),
    const Size(1280, 720),
  ]) {
    testWidgets('History lazy rows and last-row navigation at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = _HistoryRepository();
      addTearDown(repo.sessions.close);
      await tester.pumpWidget(_historyApp(repo));
      final date = DateTime(2026, 3, 12);
      final sessions = List.generate(
        600,
        (i) => WorkoutSession(title: 'Session $i', startTime: date)..id = i + 1,
      );
      repo.sessions.controller.add(sessions);
      await tester.pumpAndSettle();
      final scrollable = find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      );
      void expectLazy() {
        expect(find.byType(CustomScrollView), findsOneWidget);
        expect(scrollable, findsOneWidget);
        expect(find.byType(ListView), findsNothing);
        // At least 48px per row, plus the default 250px cache on each side.
        // Bounds scale with the viewport, not with the source length.
        expect(
          find.byType(FItem).evaluate().length,
          inInclusiveRange(1, ((size.height + 500) / 48).ceil() + 2),
        );
        expect(tester.takeException(), isNull);
      }

      expectLazy();
      expect(find.textContaining('Session 599'), findsNothing);
      await tester.scrollUntilVisible(
        find.textContaining('Session 599'),
        400,
        scrollable: scrollable,
        maxScrolls: 250,
      );
      await tester.pumpAndSettle();
      expectLazy();
      await tester.tap(find.textContaining('Session 599'));
      await tester.pumpAndSettle();
      expect(find.byType(SessionDetailPage), findsOneWidget);
      Navigator.of(tester.element(find.byType(SessionDetailPage))).pop();
      await tester.pumpAndSettle();
      final controller = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!;
      final listEnd = controller.offset;
      expect(listEnd, greaterThan(size.height));
      // Suspending drops full rows, but must not overwrite the scroll bookmark
      // with the extent of the short loading/empty placeholder.
      await tester.pumpWidget(_historyApp(repo, active: false));
      await tester.pump();
      await tester.pumpWidget(_historyApp(repo));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      repo.sessions.controller.add(sessions);
      await tester.pumpAndSettle();
      expect(controller.offset, closeTo(listEnd, 1));
      expectLazy();
      controller.jumpTo(24);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Calendar'));
      await tester.pump();
      final model = tester
          .widget<HistoryCalendar>(find.byType(HistoryCalendar))
          .model!;
      model.selectDay(date);
      final daySessions = sessions.take(200).toList();
      repo.sessions.dates.add(daySessions.map((s) => s.startTime).toList());
      repo.sessions.days.last.add(
        daySessions.map(WorkoutSessionSummary.fromSession).toList(),
      );
      repo.sessions.lookup = daySessions.last;
      await tester.pumpAndSettle();
      expect(
        tester.widget<HistoryCalendar>(find.byType(HistoryCalendar)).sliver,
        isTrue,
      );
      expectLazy();
      expect(find.text('Session 199'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Session 199'),
        400,
        scrollable: scrollable,
        maxScrolls: 100,
      );
      await tester.pumpAndSettle();
      expectLazy();
      await tester.tap(find.text('Session 199'));
      await tester.pumpAndSettle();
      expect(find.byType(SessionDetailPage), findsOneWidget);
      expect(repo.sessions.lookups, 1);
      Navigator.of(tester.element(find.byType(SessionDetailPage))).pop();
      await tester.pumpAndSettle();
      controller.jumpTo(18);
      await tester.pumpAndSettle();
      await tester.tap(find.text('List'));
      await tester.pump();
      repo.sessions.controller.add(sessions);
      await tester.pumpAndSettle();
      expect(controller.offset, closeTo(24, 1));
      await tester.tap(find.text('Calendar'));
      await tester.pump();
      repo.sessions.dates.add([date]);
      repo.sessions.days.last.add(
        daySessions.map(WorkoutSessionSummary.fromSession).toList(),
      );
      await tester.pumpAndSettle();
      expect(controller.offset, closeTo(18, 1));
      expect(model.selectedDay, date);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('sliver loading, errors, retries, empty and tab accessibility', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final repo = _HistoryRepository();
    addTearDown(repo.sessions.close);
    await tester.pumpWidget(_historyApp(repo));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repo.sessions.controller.addError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load workout history.'), findsOneWidget);
    await tester.tap(find.text('Retry history'));
    await tester.pump();
    expect(repo.sessions.watches, 2);
    repo.sessions.controller.add(const []);
    await tester.pumpAndSettle();
    expect(find.text('No workouts logged yet'), findsOneWidget);
    final tabs = tester.widget<FTabs>(find.byType(FTabs));
    expect(tabs.expands, isFalse);
    expect(tabs.children.every((entry) => entry.child is SizedBox), isTrue);
    expect(
      tester.getSemantics(find.text('List')),
      matchesSemantics(
        label: 'List\nTab 1 of 2',
        isSelected: true,
        hasSelectedState: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    // Focus the actual Forui tab and activate it using the keyboard.
    Focus.of(tester.element(find.text('Calendar'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.byType(HistoryCalendar), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    repo.sessions.dates.addError(StateError('dates'));
    repo.sessions.days.last.addError(StateError('rows'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not refresh calendar'), findsOneWidget);
    expect(find.text('Could not load this day.'), findsOneWidget);
    await tester.tap(find.text('Retry calendar'));
    await tester.tap(find.text('Retry'));
    await tester.pump();
    repo.sessions.dates.add(const []);
    repo.sessions.days.last.add(const []);
    await tester.pumpAndSettle();
    expect(find.text('No workouts on this day.'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('Pick a workout day above.'), findsOneWidget);
    await tester.tap(find.text('12'));
    await tester.pump();
    repo.sessions.days.last.add(const []);
    await tester.pumpAndSettle();
    expect(find.text('No workouts on this day.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
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

Widget _historyApp(_HistoryRepository repository, {bool active = true}) =>
    _themed(
      RepositoryScope(
        repository: repository,
        child: TabVisibilityScope(
          index: 1,
          isActive: active,
          child: const Scaffold(body: HistoryPage()),
        ),
      ),
    );

class _HistoryRepository extends Fake implements TrackerRepository {
  @override
  final _SessionsRepository sessions = _SessionsRepository();
  @override
  final gyms = _GymsRepository();
  @override
  final exercises = _ExercisesRepository();
}

class _ExercisesRepository extends Fake implements ExerciseRepository {
  @override
  Future<List<Exercise>> getAll() async => const [];
}

class _SessionsRepository extends Fake implements WorkoutSessionRepository {
  final controller = StreamController<List<WorkoutSession>>.broadcast();
  final dates = StreamController<List<DateTime>>.broadcast();
  final days = <StreamController<List<WorkoutSessionSummary>>>[];
  int dateWatches = 0;
  WorkoutSession? lookup;
  int lookups = 0;

  @override
  Future<WorkoutSession?> getById(int id) async {
    lookups++;
    return lookup;
  }

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
