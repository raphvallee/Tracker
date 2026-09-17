// Unit tests for history/calendar math (lib/pages/history/calendar_grid.dart) -
// pure functions/classes, no Isar, no widgets. The SessionDetailPage widget
// that renders this data is an integration test: test/integration/history_test.dart.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/ui/history/widgets/calendar/calendar_grid.dart';

void main() {
  // Run the DST gate with:
  // TZ=America/New_York flutter test test/ui/history/calendar_test.dart
  // Dart's local timezone is process-wide; no timezone package or mutable
  // global timezone setting is used. Other hosts still exercise calendar math.
  late bool newYork;
  setUpAll(() {
    newYork =
        DateTime(2026, 3, 8).timeZoneOffset == const Duration(hours: -5) &&
        DateTime(2026, 3, 9).timeZoneOffset == const Duration(hours: -4) &&
        DateTime(2026, 11, 2).timeZoneOffset == const Duration(hours: -5);
    if (Platform.environment['TZ'] == 'America/New_York') {
      expect(
        newYork,
        isTrue,
        reason: 'The DST gate must use the requested zone',
      );
    }
  });

  test('UTC instants straddling local midnight group by their local dates', () {
    // Derive UTC instants from local midnight so this also works on UTC hosts.
    final midnight = DateTime(2026, 3, 9);
    final before = midnight.toUtc().subtract(const Duration(minutes: 1));
    final after = midnight.toUtc().add(const Duration(minutes: 1));
    final index = WorkoutDateIndex.fromSessions([
      WorkoutSession(startTime: before),
      WorkoutSession(startTime: after),
    ]);
    expect(index.sessionsOn(DateTime(2026, 3, 8)).single.startTime, before);
    expect(index.sessionsOn(DateTime(2026, 3, 9)).single.startTime, after);
    if (newYork) {
      expect(before, DateTime.utc(2026, 3, 9, 3, 59));
      expect(after, DateTime.utc(2026, 3, 9, 4, 1));
    }
  });

  for (final month in [3, 11]) {
    test('calendar stepping across 2026 $month DST transition', () {
      final transitionDay = month == 3 ? 8 : 1;
      final today = DateTime(2026, month, transitionDay + 1);
      final previous = DateTime(2026, month, transitionDay);
      final days = {today, previous, DateTime(2026, month, transitionDay - 1)};
      expect(currentStreak(days, today), 3);
      expect(currentStreak(days.difference({today}), today), 2);
      if (newYork) {
        expect(today.difference(previous).inHours, month == 3 ? 23 : 25);
      }
    });
  }

  for (final today in [
    DateTime(2024, 3, 1),
    DateTime(2026, 5, 1),
    DateTime(2026),
  ]) {
    test('streak crosses leap/month/year boundary at $today', () {
      final days = {
        for (var back = 0; back < 3; back++)
          DateTime(today.year, today.month, today.day - back),
      };
      expect(currentStreak(days, today), 3);
      expect(currentStreak(days.difference({today}), today), 2);
    });
  }

  test('older isolated workout and a gap do not extend the streak', () {
    final today = DateTime(2026, 3, 4);
    expect(currentStreak({DateTime(2026, 3, 2)}, today), 0);
    expect(currentStreak({today, DateTime(2026, 3, 2)}, today), 1);
  });

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

    test('February 2026 (28 days) lays out in one fewer row', () {
      final grid = CalendarGrid(2026, 2);
      expect(grid.days.where((d) => d != null), hasLength(28));
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
      final today = DateTime(2026, 3, 4);
      final set = <DateTime>{
        today,
        today.subtract(const Duration(days: 1)),
        today.subtract(const Duration(days: 2)),
      };
      expect(currentStreak(set, today), 3);
    });

    test('zero when no workout at all', () {
      expect(currentStreak(<DateTime>{}, DateTime(2026, 3, 4)), 0);
    });

    test('backs up to the last workout day when today has none', () {
      final today = DateTime(2026, 3, 4);
      final set = <DateTime>{
        today.subtract(const Duration(days: 1)),
        today.subtract(const Duration(days: 2)),
      };
      expect(currentStreak(set, today), 2);
    });
  });
}
