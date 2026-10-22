import 'dart:collection';

import 'package:tracker/domain/models/workout_session.dart';

/// Immutable, normalized index of sessions by local calendar date.
///
/// Days are keyed as yyyymmdd ints. A local [DateTime] costs microseconds to
/// construct (time-zone lookup), so per-session and per-cell work stays on
/// ints; a DateTime is only built when a caller asks for one.
///
/// Building this once per session-list update avoids repeatedly scanning all
/// sessions while painting each calendar cell and calculating metrics.
class WorkoutDateIndex {
  factory WorkoutDateIndex.fromSessions(Iterable<WorkoutSession> sessions) {
    final byDay = <int, List<WorkoutSession>>{};
    for (final session in sessions) {
      final start = session.startTime;
      final key = _dayKey(start.year, start.month, start.day);
      (byDay[key] ??= <WorkoutSession>[]).add(session);
    }
    return WorkoutDateIndex._(byDay);
  }

  WorkoutDateIndex._(this._byDay) {
    final counts = <int, int>{};
    for (final key in _byDay.keys) {
      final month = key ~/ 100;
      counts[month] = (counts[month] ?? 0) + 1;
    }
    _monthCounts = counts;
    _streak = _streakEndingToday(_byDay.containsKey);
  }

  late final Map<int, int> _monthCounts;
  late final int _streak;

  final Map<int, List<WorkoutSession>> _byDay;

  /// Days with at least one session, as date-only DateTimes. Built on first
  /// access; the calendar itself uses the int-keyed lookups below.
  late final Set<DateTime> workoutDays = UnmodifiableSetView(<DateTime>{
    for (final key in _byDay.keys) _dateOf(key),
  });

  List<WorkoutSession> sessionsOn(DateTime day) =>
      _sessionsForKey(_dayKey(day.year, day.month, day.day));

  bool hasWorkoutOn(int year, int month, int day) =>
      _byDay.containsKey(_dayKey(year, month, day));

  int monthWorkoutDays(int year, int month) =>
      _monthCounts[year * 100 + month] ?? 0;

  int currentStreak() => _streak;

  List<WorkoutSession> _sessionsForKey(int key) {
    final sessions = _byDay[key];
    return sessions == null ? const [] : UnmodifiableListView(sessions);
  }
}

class CalendarGrid {
  CalendarGrid(this.year, this.month) {
    final first = DateTime(year, month);
    final leading = first.weekday - 1; // 0 for Mon, 6 for Sun
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final totalCount = leading + daysInMonth;
    final totalCells = (totalCount + 6) ~/ 7 * 7;
    final cells = List<int?>.generate(
      totalCells,
      (i) => (i < leading || i >= totalCount) ? null : i - leading + 1,
      growable: false,
    );
    days = cells;
  }

  final int year;
  final int month;

  /// 42 cells (6 rows × 7 columns); [int?] day-of-month, null for a blank slot.
  late final List<int?> days;

  DateTime dateFor(int index) => DateTime(year, month, days[index] ?? 1);
}

/// Number of consecutive days (ending today, or the last workout day if today
/// has none) that each contain at least one workout. Dates should be passed
/// date-only (midnight). Pure → unit-testable.
int currentStreak(Set<DateTime> workoutDays) {
  final keys = <int>{
    for (final day in workoutDays) _dayKey(day.year, day.month, day.day),
  };
  return _streakEndingToday(keys.contains);
}

int _dayKey(int year, int month, int day) => year * 10000 + month * 100 + day;

DateTime _dateOf(int key) =>
    DateTime(key ~/ 10000, (key ~/ 100) % 100, key % 100);

int _previousDayKey(int key) {
  final day = DateTime.utc(key ~/ 10000, (key ~/ 100) % 100, key % 100 - 1);
  return _dayKey(day.year, day.month, day.day);
}

int _streakEndingToday(bool Function(int key) hasDay) {
  final now = DateTime.now();
  var key = _dayKey(now.year, now.month, now.day);
  if (!hasDay(key)) key = _previousDayKey(key);
  var streak = 0;
  while (hasDay(key)) {
    streak++;
    key = _previousDayKey(key);
  }
  return streak;
}
