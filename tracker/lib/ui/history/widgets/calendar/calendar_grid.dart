import 'dart:collection';

import 'package:tracker/domain/models/workout_session.dart';

/// Lazy, immutable index of session start times by local calendar date.
///
/// Reading a local DateTime's year/month/day costs a time-zone lookup the
/// first time (microseconds each, slowest on Windows), so resolving every
/// session up front made the first calendar frame O(history). Instead the
/// index keeps the start times sorted newest first and only resolves the
/// sessions of a month when that month is asked for: a binary search over the
/// raw instants finds the month's sessions, and only those are converted to
/// local dates. Results are cached per month.
///
/// The binary search window is the UTC month widened by a day on each side,
/// which always contains the local month (UTC offsets stay within 24 h), and
/// every candidate is then checked against its real local date, so DST
/// transitions and midnight time-zone changes are classified exactly like a
/// full scan would.
class WorkoutDateIndex {
  /// [newestFirst] must be sorted by instant, newest first (the order
  /// `WorkoutSessionRepository.getStartTimesSync` returns).
  WorkoutDateIndex(List<DateTime> newestFirst) : _starts = newestFirst {
    assert(_isNewestFirst(newestFirst), 'start times must be newest first');
  }

  /// Convenience for in-memory session lists in any order.
  factory WorkoutDateIndex.fromSessions(Iterable<WorkoutSession> sessions) =>
      WorkoutDateIndex(
        [for (final session in sessions) session.startTime]
          ..sort((a, b) => b.compareTo(a)),
      );

  final List<DateTime> _starts;
  final Map<int, Set<int>> _monthDays = <int, Set<int>>{};
  int? _streakDay;
  int _streak = 0;

  bool get isEmpty => _starts.isEmpty;

  /// Days of [month] (1-31) with at least one workout.
  Set<int> workoutDaysIn(int year, int month) {
    final normalized = DateTime.utc(year, month);
    return _monthDays[normalized.year * 100 + normalized.month] ??=
        UnmodifiableSetView(_resolveMonth(normalized.year, normalized.month));
  }

  bool hasWorkoutOn(int year, int month, int day) =>
      workoutDaysIn(year, month).contains(day);

  int monthWorkoutDays(int year, int month) =>
      workoutDaysIn(year, month).length;

  /// Consecutive workout days ending today (or yesterday when today has no
  /// workout yet). Cached until the local date changes.
  int currentStreak() {
    final now = DateTime.now();
    final today = _dayKey(now.year, now.month, now.day);
    if (_streakDay != today) {
      _streak = _streakEndingOn(today, _hasDayKey);
      _streakDay = today;
    }
    return _streak;
  }

  bool _hasDayKey(int key) =>
      hasWorkoutOn(key ~/ 10000, (key ~/ 100) % 100, key % 100);

  Set<int> _resolveMonth(int year, int month) {
    final from = DateTime.utc(year, month, 0).microsecondsSinceEpoch;
    final to = DateTime.utc(year, month + 1, 2).microsecondsSinceEpoch;
    final days = <int>{};
    for (var i = _firstBefore(to); i < _starts.length; i++) {
      final start = _starts[i];
      if (start.microsecondsSinceEpoch < from) break;
      if (start.year == year && start.month == month) days.add(start.day);
    }
    return days;
  }

  /// Index of the first start strictly before [micros].
  int _firstBefore(int micros) {
    var lo = 0;
    var hi = _starts.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_starts[mid].microsecondsSinceEpoch >= micros) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  static bool _isNewestFirst(List<DateTime> starts) {
    for (var i = 1; i < starts.length; i++) {
      if (starts[i].isAfter(starts[i - 1])) return false;
    }
    return true;
  }
}

class CalendarGrid {
  CalendarGrid(this.year, this.month) {
    final first = DateTime(year, month);
    final leading = first.weekday - 1;
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

  late final List<int?> days;

  DateTime dateFor(int index) => DateTime(year, month, days[index] ?? 1);
}

int currentStreak(Set<DateTime> workoutDays) {
  final keys = <int>{
    for (final day in workoutDays) _dayKey(day.year, day.month, day.day),
  };
  final now = DateTime.now();
  return _streakEndingOn(_dayKey(now.year, now.month, now.day), keys.contains);
}

int _dayKey(int year, int month, int day) => year * 10000 + month * 100 + day;

int _previousDayKey(int key) {
  final day = DateTime.utc(key ~/ 10000, (key ~/ 100) % 100, key % 100 - 1);
  return _dayKey(day.year, day.month, day.day);
}

int _streakEndingOn(int today, bool Function(int key) hasDay) {
  var key = today;
  if (!hasDay(key)) key = _previousDayKey(key);
  var streak = 0;
  while (hasDay(key)) {
    streak++;
    key = _previousDayKey(key);
  }
  return streak;
}
