import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/ui/history/view_models/calendar_view_model.dart';

import 'counting_sessions.dart';

void main() {
  testWidgets('active midnight refreshes without source reads; timers cancel', (
    tester,
  ) async {
    var now = DateTime(2026, 3, 4, 23, 59, 59);
    final model = CalendarViewModel(now: () => now);
    final sessions = CountingSessions([
      WorkoutSession(startTime: DateTime(2026, 3, 3)),
    ]);
    model.updateSessions(sessions);
    final index = model.dateIndex;
    final grid = model.grid;
    var notifications = 0;
    model.addListener(() => notifications++);
    expect(model.streak, 1);
    model.setActive(true);
    model.setActive(true);
    now = DateTime(2026, 3, 5);
    await tester.pump(const Duration(seconds: 1));
    expect(model.today, now);
    expect(model.streak, 0);
    expect(model.dateIndex, same(index));
    expect(model.grid, same(grid));
    expect(sessions.reads, 1);
    expect(notifications, 1);

    model.setActive(false);
    now = DateTime(2026, 3, 7);
    await tester.pump(const Duration(days: 2));
    expect(notifications, 1);
    expect(model.today, DateTime(2026, 3, 5));
    model.setActive(true);
    expect(model.today, now);
    expect(model.dateIndex, same(index));
    expect(sessions.reads, 1);
    model.dispose();
    now = DateTime(2026, 3, 8);
    await tester.pump(const Duration(days: 1));
    expect(notifications, 1);
  });

  testWidgets(
    'lifecycle resume refreshes after midnight and disposes listener',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      var now = DateTime(2026, 3, 4, 23, 59, 59);
      final model = CalendarViewModel(now: () => now);
      final sessions = CountingSessions([
        WorkoutSession(startTime: DateTime(2026, 3, 3)),
      ]);
      model.updateSessions(sessions);
      final index = model.dateIndex;
      model.setActive(true);
      var notifications = 0;
      model.addListener(() => notifications++);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = DateTime(2026, 3, 6);
      await tester.pump(const Duration(days: 2));
      expect(notifications, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(model.today, now);
      expect(model.streak, 0);
      expect(notifications, 1);
      expect(model.dateIndex, same(index));
      expect(sessions.reads, 1);
      model.dispose();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(notifications, 1);
    },
  );

  for (final month in [3, 11]) {
    testWidgets(
      'midnight alarm follows local calendar across DST month $month',
      (tester) async {
        final transition = month == 3 ? 8 : 1;
        var now = DateTime(2026, month, transition);
        final model = CalendarViewModel(now: () => now);
        final sessions = CountingSessions([WorkoutSession(startTime: now)]);
        model.updateSessions(sessions);
        final index = model.dateIndex;
        model.setActive(true);
        final next = DateTime(2026, month, transition + 1);
        final duration = next.difference(now);
        now = next.subtract(const Duration(seconds: 1));
        await tester.pump(duration - const Duration(seconds: 1));
        expect(model.today, DateTime(2026, month, transition));
        now = next;
        await tester.pump(const Duration(seconds: 1));
        expect(model.today, next);
        expect(model.streak, 1);
        // A normal DST transition is not a device timezone change.
        expect(model.dateIndex, same(index));
        expect(sessions.reads, 1);
        model.dispose();
      },
    );
  }

  test(
    'standalone adapter releases source sessions; navigation never rescans',
    () {
      final model = CalendarViewModel(initialDate: DateTime(2026, 3, 4));
      addTearDown(model.dispose);
      final sessions = CountingSessions(
        List.generate(
          1000,
          (index) =>
              WorkoutSession(startTime: DateTime(2026, 3, index % 28 + 1)),
        ),
      );

      model.updateSessions(sessions);
      final grid = model.grid;
      expect(sessions.reads, 1000);
      final index = model.dateIndex;
      final days = model.daysWithWorkouts;
      expect(sessions.reads, 1000);
      expect(model.monthWorkoutDays, 28);
      expect(model.grid, same(grid));
      expect(model.daysWithWorkouts, same(days));

      model.selectDay(DateTime(2026, 3, 10));
      expect(model.sessionsOn(model.selectedDay!), isNotEmpty);
      model.goMonth(-1);
      expect(model.selectedDay, isNull);
      expect(model.grid, isNot(same(grid)));
      expect(model.daysWithWorkouts, isEmpty);
      expect(model.monthWorkoutDays, 0);
      model.goMonth(1);
      model.selectDay(DateTime(2026, 3, 10));
      expect(model.dateIndex, same(index));
      expect(model.selectedDay, DateTime(2026, 3, 10));
      expect(sessions.reads, 1000);
    },
  );

  test('replacement and empty snapshots invalidate lazily, not navigation', () {
    final model = CalendarViewModel(initialDate: DateTime(2026, 1, 1));
    addTearDown(model.dispose);
    final old = CountingSessions([
      WorkoutSession(startTime: DateTime(2026, 2, 12)),
    ]);
    model.updateSessions(old);
    final original = model.dateIndex;
    model.goMonth(1);
    model.selectDay(DateTime(2026, 2, 12));
    final grid = model.grid;
    final replacement = CountingSessions([
      WorkoutSession(title: 'Replacement', startTime: DateTime(2026, 2, 12)),
    ]);
    model.updateSessions(replacement);
    expect(replacement.reads, 1);
    expect(model.dateIndex, isNot(same(original)));
    expect(model.sessionsOn(model.selectedDay!).single.title, 'Replacement');
    expect(replacement.reads, 1);

    model.updateSessions(const []);
    expect(model.sessionsOn(model.selectedDay!), isEmpty);
    expect(model.daysWithWorkouts, isEmpty);
    expect(model.grid, same(grid));
    expect(model.year, 2026);
    expect(model.month, 2);
    expect(model.selectedDay, DateTime(2026, 2, 12));
    expect(old.reads, 1);
    expect(replacement.reads, 1);
  });

  test('snapshots received before first activation only index the latest', () {
    final model = CalendarViewModel(initialDate: DateTime(2026, 3, 1));
    addTearDown(model.dispose);
    final old = CountingSessions([
      WorkoutSession(startTime: DateTime(2026, 2)),
    ]);
    final latest = CountingSessions([
      WorkoutSession(startTime: DateTime(2026, 3)),
    ]);
    model.updateSessions(old);
    model.updateSessions(latest);
    expect(old.reads, 1);
    expect(latest.reads, 1);
    expect(model.monthWorkoutDays, 1);
    expect(old.reads, 1);
    expect(latest.reads, 1);
  });
}
