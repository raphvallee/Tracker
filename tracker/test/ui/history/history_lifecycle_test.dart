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
import 'package:tracker/routing/tab_navigation.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/history/view_models/calendar_view_model.dart';
import 'package:tracker/ui/history/widgets/calendar/history_calendar.dart';
import 'package:tracker/ui/history/widgets/history_page.dart';
import 'package:tracker/ui/history/widgets/session_detail_page.dart';

void main() {
  testWidgets(
    'hidden List drops payloads, ignores late events and refreshes once',
    (tester) async {
      final repo = _Repository();
      await tester.pumpWidget(_app(repo, active: false));
      expect(repo.sessions.all, isEmpty);
      expect(repo.gyms.reads, 0);
      await tester.pumpWidget(_app(repo));
      expect(repo.sessions.all.length, 1);
      final first = repo.sessions.all.single;
      first.emit([
        WorkoutSession(startTime: DateTime(2026, 3, 1), title: 'Full payload'),
      ]);
      await tester.pumpAndSettle();
      expect(find.textContaining('Full payload'), findsOneWidget);
      await tester.pumpWidget(_app(repo, active: false));
      expect(first.cancelled, isTrue);
      expect(find.textContaining('Full payload'), findsNothing);
      first.emit([
        WorkoutSession(startTime: DateTime(2026, 3, 1), title: 'Obsolete'),
      ]);
      first.fail();
      await tester.pump();
      expect(find.textContaining('Obsolete'), findsNothing);
      expect(find.text('Retry history'), findsNothing);
      for (var i = 0; i < 3; i++) {
        await tester.pumpWidget(_app(repo));
        expect(repo.sessions.all.length, i + 2);
        expect(repo.sessions.live, 1);
        // No initial getAll + watcher: the fake has no getAll implementation.
        repo.sessions.all.last.emit(const []);
        await tester.pumpWidget(_app(repo, active: false));
        expect(repo.sessions.live, 0);
      }
      expect(repo.sessions.dates, isEmpty);
      expect(repo.sessions.days, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      first.fail();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('List app suspension and hidden repository swap refresh once', (
    tester,
  ) async {
    final first = _Repository();
    final second = _Repository();
    void lifecycle(AppLifecycleState state) =>
        tester.binding.handleAppLifecycleStateChanged(state);
    lifecycle(AppLifecycleState.resumed);
    await tester.pumpWidget(_app(first));
    first.sessions.all.single.emit([
      WorkoutSession(startTime: DateTime(2026), title: 'Old list'),
    ]);
    await tester.pumpAndSettle();
    lifecycle(AppLifecycleState.inactive);
    lifecycle(AppLifecycleState.hidden);
    expect(first.sessions.live, 0);
    await tester.pumpWidget(_app(second));
    tester.binding.scheduleForcedFrame();
    await tester.pump(); // Apply repository replacement despite hidden frames.
    expect(second.sessions.all, isEmpty);
    expect(second.gyms.reads, 0);
    lifecycle(AppLifecycleState.inactive);
    expect(second.sessions.live, 0);
    lifecycle(AppLifecycleState.resumed);
    await tester.pump();
    expect(second.sessions.all.length, 1);
    expect(second.sessions.dates, isEmpty);
    second.sessions.all.single.emit([
      WorkoutSession(startTime: DateTime(2026), title: 'New list'),
    ]);
    first.sessions.all.single.emit([
      WorkoutSession(startTime: DateTime(2000), title: 'Obsolete list'),
    ]);
    first.sessions.all.single.fail();
    await tester.pumpAndSettle();
    expect(find.textContaining('New list'), findsOneWidget);
    expect(find.textContaining('Obsolete list'), findsNothing);
    expect(find.text('Retry history'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(second.sessions.live, 0);
  });

  testWidgets(
    'Calendar retains navigation and refreshes only its two sources',
    (tester) async {
      final repo = _Repository();
      await tester.pumpWidget(_app(repo));
      await tester.tap(find.text('Calendar'));
      await tester.pump();
      final model = tester
          .widget<HistoryCalendar>(find.byType(HistoryCalendar))
          .model!;
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pump();
      await tester.tap(find.text('12'));
      await tester.pump();
      final day = model.selectedDay!;
      repo.sessions.dates.last.emit([day]);
      repo.sessions.days.last.emit([_row('Before', day)]);
      await tester.pumpAndSettle();
      final index = model.dateIndex;
      final grid = model.grid;
      final occupied = model.daysWithWorkouts;
      final initialDays = repo.sessions.days.length;
      final oldDates = repo.sessions.dates.last;
      final oldDay = repo.sessions.days.last;
      for (var i = 0; i < 3; i++) {
        await tester.pumpWidget(_app(repo, active: false));
        expect(repo.sessions.live, 0);
        expect(model.dayRows, isEmpty);
        oldDates.emit([DateTime(2000)]);
        oldDates.fail();
        oldDay.emit([_row('Stale', day)]);
        oldDay.fail();
        expect(model.dateIndex, same(index));
        expect(model.dayRows, isEmpty);
        expect(model.datesError, isNull);
        expect(model.dayError, isNull);
        await tester.pumpWidget(_app(repo));
        expect(repo.sessions.dates.length, i + 2);
        expect(repo.sessions.days.length, initialDays + i + 1);
        expect(repo.sessions.live, 2);
        expect(repo.sessions.all.length, 1);
        expect(model.datesLoading, isTrue);
        expect(model.dayLoading, isTrue);
        oldDates.emit([DateTime(2000)]);
        oldDates.fail();
        oldDay.emit([_row('Late after resume', day)]);
        oldDay.fail();
        expect(model.dateIndex, same(index));
        expect(model.dayRows, isEmpty);
        expect(model.datesError, isNull);
        expect(model.dayError, isNull);
        expect(model.selectedDay, day);
        expect(model.grid, same(grid));
        repo.sessions.dates.last.emit([day]);
        repo.sessions.days.last.emit([_row('Refreshed $i', day)]);
        await tester.pumpAndSettle();
        expect(model.dateIndex, same(index));
        expect(model.daysWithWorkouts, same(occupied));
        expect(find.text('Refreshed $i'), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      expect(repo.sessions.live, 0);
      oldDates.fail();
      oldDay.fail();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('app and top tab combine without inactive focus churn', (
    tester,
  ) async {
    final repo = _Repository();
    void lifecycle(AppLifecycleState state) =>
        tester.binding.handleAppLifecycleStateChanged(state);
    lifecycle(AppLifecycleState.resumed);
    await tester.pumpWidget(_app(repo));
    expect(repo.sessions.all.length, 1);
    lifecycle(AppLifecycleState.inactive);
    lifecycle(AppLifecycleState.resumed);
    await tester.pump();
    expect(repo.sessions.all.length, 1);
    expect(repo.sessions.live, 1);
    await tester.tap(find.text('Calendar'));
    await tester.pump();
    lifecycle(AppLifecycleState.inactive);
    expect(repo.sessions.live, 2);
    lifecycle(AppLifecycleState.hidden);
    expect(repo.sessions.live, 0);
    lifecycle(AppLifecycleState.paused);
    await tester.pumpWidget(_app(repo, active: false));
    lifecycle(AppLifecycleState.hidden);
    lifecycle(AppLifecycleState.inactive);
    lifecycle(AppLifecycleState.resumed);
    await tester.pump();
    expect(repo.sessions.dates.length, 1); // App resumed, top tab still hidden.
    expect(repo.sessions.live, 0);
    await tester.pumpWidget(_app(repo));
    expect(repo.sessions.dates.length, 2);
    expect(repo.sessions.days.length, 2);
    lifecycle(AppLifecycleState.inactive);
    lifecycle(AppLifecycleState.resumed);
    expect(repo.sessions.dates.length, 2);
    lifecycle(AppLifecycleState.inactive);
    lifecycle(AppLifecycleState.hidden);
    lifecycle(AppLifecycleState.paused);
    lifecycle(AppLifecycleState.detached);
    expect(repo.sessions.live, 0);
    await tester.pumpWidget(_app(repo, active: false));
    await tester.pumpWidget(_app(repo)); // Top tab active, app still detached.
    expect(repo.sessions.dates.length, 2);
    lifecycle(AppLifecycleState.resumed);
    await tester.pump(); // Apply the queued tab dependency once frames resume.
    expect(repo.sessions.dates.length, 3);
    expect(repo.sessions.days.length, 3);
    await tester.pumpWidget(const SizedBox.shrink());
    lifecycle(AppLifecycleState.inactive);
    lifecycle(AppLifecycleState.resumed);
    expect(repo.sessions.live, 0);
    expect(repo.sessions.dates.length, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'initial hidden app and hidden repository replacement do not query',
    (tester) async {
      final first = _Repository();
      final second = _Repository();
      void lifecycle(AppLifecycleState state) =>
          tester.binding.handleAppLifecycleStateChanged(state);
      lifecycle(AppLifecycleState.resumed);
      lifecycle(AppLifecycleState.inactive);
      lifecycle(AppLifecycleState.hidden);
      await tester.pumpWidget(_app(first));
      expect(first.sessions.live, 0);
      expect(first.sessions.all, isEmpty);
      lifecycle(AppLifecycleState.inactive);
      lifecycle(AppLifecycleState.resumed);
      await tester.pump();
      await tester.tap(find.text('Calendar'));
      await tester.pump();
      final model = tester
          .widget<HistoryCalendar>(find.byType(HistoryCalendar))
          .model!;
      final day = model.selectedDay!;
      first.sessions.dates.last.emit([day]);
      first.sessions.days.last.emit([_row('Old', day)]);
      await tester.pumpAndSettle();
      await tester.pumpWidget(_app(first, active: false));
      await tester.pumpWidget(_app(second, active: false));
      expect(first.sessions.live, 0);
      expect(second.sessions.live, 0);
      expect(second.sessions.all, isEmpty);
      expect(second.sessions.dates, isEmpty);
      expect(second.gyms.reads, 0);
      expect(model.dateIndex.workoutDays, isEmpty);
      first.sessions.dates.last.emit([DateTime(2000)]);
      first.sessions.dates.last.fail();
      first.sessions.days.last.fail();
      expect(model.dateIndex.workoutDays, isEmpty);
      expect(model.datesError, isNull);
      expect(model.dayError, isNull);
      await tester.pumpWidget(_app(second));
      expect(second.sessions.all, isEmpty);
      expect(second.sessions.dates.length, 1);
      expect(second.sessions.days.length, 1);
      expect(second.sessions.requestedDays.single, day);
      second.sessions.dates.last.emit([day, day]);
      second.sessions.days.last.emit([_row('New', day)]);
      await tester.pumpAndSettle();
      expect(model.selectedDay, day);
      expect(model.dateIndex.countOn(day), 2);
      expect(find.text('New'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'detail route coverage keeps history updating and default scope is active',
    (tester) async {
      final repo = _Repository();
      await tester.pumpWidget(_app(repo, active: null));
      repo.sessions.all.single.emit([
        WorkoutSession(startTime: DateTime(2026, 3, 1), title: 'Open detail'),
      ]);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Open detail'));
      await tester.pumpAndSettle();
      expect(find.byType(SessionDetailPage), findsOneWidget);
      expect(repo.sessions.live, 1);
      expect(repo.sessions.all.length, 1);
      repo.sessions.all.single.emit([
        WorkoutSession(
          startTime: DateTime(2026, 3, 1),
          title: 'Changed behind route',
        ),
      ]);
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(SessionDetailPage))).pop();
      await tester.pumpAndSettle();
      expect(find.textContaining('Changed behind route'), findsOneWidget);
      expect(repo.sessions.all.length, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'managed calendar clock pauses and resumes with exactly one refresh',
    (tester) async {
      var now = DateTime(2026, 3, 4, 23, 59, 59);
      final repo = _Sessions();
      final model = CalendarViewModel(
        now: () => now,
        observeAppLifecycle: false,
      );
      model.setHistoryActive(false);
      model.bindRepository(repo);
      model.setCalendarMode(true);
      expect(repo.live, 0);
      model.setHistoryActive(true);
      repo.dates.single.emit([DateTime(2026, 3, 3)]);
      final index = model.dateIndex;
      now = DateTime(2026, 3, 5);
      await tester.pump(const Duration(seconds: 1));
      expect(model.today, now);
      expect(model.dateIndex, same(index));
      expect(repo.dates.length, 1);
      model.setHistoryActive(false);
      now = DateTime(2026, 3, 7);
      await tester.pump(const Duration(days: 2));
      expect(model.today, DateTime(2026, 3, 5));
      model.setHistoryActive(true);
      model.setHistoryActive(true);
      expect(model.today, now);
      expect(repo.dates.length, 2);
      expect(repo.days.length, 2);
      expect(model.dateIndex, same(index));
      model.dispose();
      now = DateTime(2026, 3, 8);
      await tester.pump(const Duration(days: 1));
      expect(model.today, DateTime(2026, 3, 7));
      expect(repo.live, 0);
    },
  );
}

Widget _app(_Repository repository, {bool? active = true}) {
  Widget child = RepositoryScope(
    repository: repository,
    child: const Scaffold(body: HistoryPage()),
  );
  if (active != null) {
    child = TabVisibilityScope(index: 1, isActive: active, child: child);
  }
  return MaterialApp(
    builder: (context, child) =>
        FTheme(data: FTheme.neutral.light.desktop, child: child!),
    home: child,
  );
}

WorkoutSessionSummary _row(String title, DateTime day) => WorkoutSessionSummary(
  id: 1,
  title: title,
  startTime: day,
  setCount: 2,
  gymId: null,
);

class _Repository extends Fake implements TrackerRepository {
  @override
  final _Sessions sessions = _Sessions();
  @override
  final _Gyms gyms = _Gyms();
}

class _Gyms extends Fake implements GymRepository {
  int reads = 0;
  @override
  Future<List<Gym>> getAll() async {
    reads++;
    return const [];
  }
}

class _Sessions extends Fake implements WorkoutSessionRepository {
  final all = <_LateStream<List<WorkoutSession>>>[];
  final dates = <_LateStream<List<DateTime>>>[];
  final days = <_LateStream<List<WorkoutSessionSummary>>>[];
  final requestedDays = <DateTime>[];
  int get live => [...all, ...dates, ...days].where((s) => !s.cancelled).length;
  @override
  Stream<List<WorkoutSession>> watchAll() {
    final stream = _LateStream<List<WorkoutSession>>();
    all.add(stream);
    return stream;
  }

  @override
  Stream<List<DateTime>> watchStartTimes() {
    final stream = _LateStream<List<DateTime>>();
    dates.add(stream);
    return stream;
  }

  @override
  Stream<List<WorkoutSessionSummary>> watchSummariesForDate(DateTime day) {
    requestedDays.add(day);
    final stream = _LateStream<List<WorkoutSessionSummary>>();
    days.add(stream);
    return stream;
  }
}

// A hostile source emits during cancellation and even afterwards. This tests
// owner generation guards rather than relying on Dart streams to mask mistakes.
class _LateStream<T> extends Stream<T> {
  void Function(T)? _data;
  Function? _error;
  bool cancelled = false;
  void emit(T value) => _data!(value);
  void fail() => Function.apply(_error!, [StateError('late')]);
  @override
  StreamSubscription<T> listen(
    void Function(T)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    _data = onData;
    _error = onError;
    return _Subscription<T>(() {
      cancelled = true;
      fail();
    });
  }
}

class _Subscription<T> extends Fake implements StreamSubscription<T> {
  _Subscription(this.onCancel);
  final void Function() onCancel;
  @override
  Future<void> cancel() async => onCancel();
}
