// Unit tests for history/calendar math (lib/pages/history/calendar_grid.dart) -
// pure functions/classes, no Isar, no widgets. The SessionDetailPage widget
// that renders this data is an integration test: test/ui/history/history_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/ui/history/widgets/calendar/calendar_grid.dart';

void main() {
  group('CalendarGrid math', () {
    test('Monday-start grid, correct leading blanks and day count', () {
      // March 2026 starts on a Sunday → 6 leading blanks (Mon..Sat of week),
      // then days 1..31. Verify via the last day landing in its cell.
      final grid = CalendarGrid(2026, 3);
      expect(grid.days, hasLength(42));
      // March 1 2026 is a Sunday: index 6 (0=Mon..6=Sun).
      expect(grid.days.sublist(0, 6).where((d) => d != null), isEmpty);
      expect(grid.days[6], 1);
      expect(grid.days[36], 31); // March has 31 days
      // Cells after the month end are blank.
      expect(grid.days.sublist(37).where((d) => d != null), isEmpty);
    });

    test('dateFor maps an index back to a real date', () {
      final grid = CalendarGrid(2026, 3);
      expect(grid.dateFor(6), DateTime(2026, 3, 1));
    });
  });

  group('WorkoutDateIndex', () {
    test('normalizes sessions, groups days, and computes month metrics', () {
      final index = WorkoutDateIndex.fromSessions([
        WorkoutSession(startTime: DateTime(2026, 3, 4, 9)),
        WorkoutSession(startTime: DateTime(2026, 3, 4, 18)),
        WorkoutSession(startTime: DateTime(2026, 4, 1, 9)),
      ]);

      expect(index.sessionsOn(DateTime(2026, 3, 4)), hasLength(2));
      expect(index.monthWorkoutDays(2026, 3), 1);
      expect(index.monthWorkoutDays(2026, 4), 1);
      expect(index.workoutDays, contains(DateTime(2026, 3, 4)));
    });

    test('exposes immutable cached collections', () {
      final index = WorkoutDateIndex.fromSessions([
        WorkoutSession(startTime: DateTime(2026, 3, 4)),
      ]);

      expect(
        () => index.workoutDays.add(DateTime(2026, 3, 5)),
        throwsUnsupportedError,
      );
      expect(
        () => index.sessionsOn(DateTime(2026, 3, 4)).clear(),
        throwsUnsupportedError,
      );
    });
  });

  group('currentStreak', () {
    test('counts consecutive workout days ending today', () {
      final today = DateUtils.dateOnly(DateTime.now());
      final set = <DateTime>{
        today,
        today.subtract(const Duration(days: 1)),
        today.subtract(const Duration(days: 2)),
      };
      expect(currentStreak(set), 3);
    });

    test('zero when no workout at all', () {
      expect(currentStreak(<DateTime>{}), 0);
    });

    test('backs up to the last workout day when today has none', () {
      final today = DateUtils.dateOnly(DateTime.now());
      final set = <DateTime>{
        today.subtract(const Duration(days: 1)),
        today.subtract(const Duration(days: 2)),
      };
      expect(currentStreak(set), 2);
    });
  });
}
