import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/ui/history/view_models/calendar_view_model.dart';

import 'counting_sessions.dart';

void main() {
  test('first calendar access reads N sessions; navigation never rescans', () {
    final model = CalendarViewModel(initialDate: DateTime(2026, 3, 4));
    addTearDown(model.dispose);
    final sessions = CountingSessions(
      List.generate(
        1000,
        (index) => WorkoutSession(startTime: DateTime(2026, 3, index % 28 + 1)),
      ),
    );

    model.updateSessions(sessions);
    final grid = model.grid;
    expect(sessions.reads, 0);
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
    model.updateSessions(sessions); // Unchanged snapshot on remount.
    expect(model.dateIndex, same(index));
    expect(model.selectedDay, DateTime(2026, 3, 10));
    expect(sessions.reads, 1000);
  });

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
    expect(replacement.reads, 0);
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
    expect(old.reads, 0);
    expect(latest.reads, 0);
    expect(model.monthWorkoutDays, 1);
    expect(old.reads, 0);
    expect(latest.reads, 1);
  });
}
