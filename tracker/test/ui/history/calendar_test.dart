import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/ui/history/widgets/calendar/calendar_grid.dart';

void main() {
  group('CalendarGrid math', () {
    test('Monday-start grid, correct leading blanks and day count', () {
      final grid = CalendarGrid(2026, 3);
      expect(grid.days, hasLength(42));
      expect(grid.days.sublist(0, 6).where((d) => d != null), isEmpty);
      expect(grid.days[6], 1);
      expect(grid.days[36], 31);
      expect(grid.days.sublist(37).where((d) => d != null), isEmpty);
    });

    test('dateFor maps an index back to a real date', () {
      final grid = CalendarGrid(2026, 3);
      expect(grid.dateFor(6), DateTime(2026, 3, 1));
    });
  });

  group('WorkoutDateIndex', () {
    test('groups days and computes month metrics', () {
      final index = WorkoutDateIndex.fromSessions([
        WorkoutSession(startTime: DateTime(2026, 3, 4, 9)),
        WorkoutSession(startTime: DateTime(2026, 3, 4, 18)),
        WorkoutSession(startTime: DateTime(2026, 4, 1, 9)),
      ]);

      expect(index.workoutDaysIn(2026, 3), {4});
      expect(index.hasWorkoutOn(2026, 3, 4), isTrue);
      expect(index.hasWorkoutOn(2026, 3, 5), isFalse);
      expect(index.monthWorkoutDays(2026, 3), 1);
      expect(index.monthWorkoutDays(2026, 4), 1);
      expect(index.monthWorkoutDays(2026, 5), 0);
      expect(index.isEmpty, isFalse);
      expect(WorkoutDateIndex(const []).isEmpty, isTrue);
    });

    test('exposes immutable cached collections', () {
      final index = WorkoutDateIndex.fromSessions([
        WorkoutSession(startTime: DateTime(2026, 3, 4)),
      ]);

      expect(() => index.workoutDaysIn(2026, 3).add(5), throwsUnsupportedError);
      expect(
        identical(index.workoutDaysIn(2026, 3), index.workoutDaysIn(2026, 3)),
        isTrue,
      );
    });

    test('normalizes out-of-range months like DateTime', () {
      final index = WorkoutDateIndex.fromSessions([
        WorkoutSession(startTime: DateTime(2027, 1, 2)),
        WorkoutSession(startTime: DateTime(2025, 12, 31)),
      ]);

      expect(index.workoutDaysIn(2026, 13), {2});
      expect(index.workoutDaysIn(2026, 0), {31});
    });

    test('classifies sessions at month edges by their local date', () {
      final edges = [
        DateTime(2026, 2, 28, 23, 59, 59),
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 31, 23, 59, 59, 999),
        DateTime(2026, 4, 1),
        DateTime(2026, 12, 31, 23, 30),
        DateTime(2027, 1, 1, 0, 30),
      ];
      final index = WorkoutDateIndex.fromSessions([
        for (final start in edges) WorkoutSession(startTime: start),
      ]);

      expect(index.workoutDaysIn(2026, 2), {28});
      expect(index.workoutDaysIn(2026, 3), {1, 31});
      expect(index.workoutDaysIn(2026, 4), {1});
      expect(index.workoutDaysIn(2026, 12), {31});
      expect(index.workoutDaysIn(2027, 1), {1});
    });

    test('matches a full local-date scan for every month and the streak', () {
      // Random history over ~3 years, including future sessions and several
      // per day; Isar-like local DateTimes built from UTC instants.
      final random = Random(42);
      final now = DateTime.now();
      final starts = <DateTime>[
        for (var i = 0; i < 1500; i++)
          DateTime.fromMicrosecondsSinceEpoch(
            now.microsecondsSinceEpoch +
                (30 * Duration.secondsPerDay -
                        random.nextInt(1100 * Duration.secondsPerDay)) *
                    Duration.microsecondsPerSecond +
                random.nextInt(Duration.microsecondsPerSecond),
            isUtc: true,
          ).toLocal(),
        // An unbroken run ending today, so the streak crosses months.
        for (var d = 0; d < 45; d++)
          DateTime(now.year, now.month, now.day - d, 7 + d % 12),
      ];
      final index = WorkoutDateIndex.fromSessions([
        for (final start in starts) WorkoutSession(startTime: start),
      ]);

      for (var m = -40; m <= 2; m++) {
        final month = DateTime(now.year, now.month + m);
        final expected = {
          for (final start in starts)
            if (start.year == month.year && start.month == month.month)
              start.day,
        };
        expect(
          index.workoutDaysIn(month.year, month.month),
          expected,
          reason: '${month.year}-${month.month}',
        );
      }
      expect(
        index.currentStreak(),
        currentStreak({for (final start in starts) DateUtils.dateOnly(start)}),
      );
      expect(index.currentStreak(), greaterThanOrEqualTo(45));
    });

    test('rejects start times that are not newest first', () {
      expect(
        () => WorkoutDateIndex([DateTime(2026, 3, 1), DateTime(2026, 3, 2)]),
        throwsAssertionError,
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
