import 'dart:collection';

import 'package:tracker/domain/models/workout_session.dart';

/// Lazy, immutable index of session start times by local calendar date.
///
/// Reading a local DateTime's year/month/day costs a time-zone lookup the
/// first time (microseconds each, slowest on Windows), so resolving every
/// session up front made the first History frame O(history). Instead the
/// index keeps the start times sorted newest first and only resolves what is
/// asked for: a month's sessions (a binary search over the raw instants
/// finds them, and only those are converted to local dates), or the month of
/// one list position. Results are cached.
///
/// The binary search window is the UTC month (or day) widened by a day on
/// each side, which always contains the local one (UTC offsets stay within
/// 24 h), and every candidate is then checked against its real local date,
/// so DST transitions and midnight time-zone changes are classified exactly
/// like a full scan would.
class WorkoutDateIndex {
  /// [newestFirst] must be sorted by instant, newest first (the order
  /// `WorkoutSessionRepository.getTimelineSync` returns).
  WorkoutDateIndex(List<DateTime> newestFirst)
    : _starts = newestFirst,
      _monthKeys = List<int>.filled(newestFirst.length, 0) {
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
  final Map<int, int> _monthCounts = <int, int>{};

  /// Local month of each list position, resolved on first use (0: not yet).
  final List<int> _monthKeys;
  int? _streakDay;
  int _streak = 0;

  bool get isEmpty => _starts.isEmpty;

  /// Sessions in the index.
  int get length => _starts.length;

  /// Start time of the session at [index], newest first.
  DateTime startAt(int index) => _starts[index];

  /// Local month of the session at [index], as year * 100 + month.
  int monthKeyAt(int index) {
    final cached = _monthKeys[index];
    if (cached != 0) return cached;
    final start = _starts[index];
    return _monthKeys[index] = start.year * 100 + start.month;
  }

  /// Whether the session at [index] is the newest of its month: the list
  /// puts the month's heading above it.
  bool startsMonth(int index) =>
      index == 0 || monthKeyAt(index) != monthKeyAt(index - 1);

  /// Sessions starting in [month] (1-12), local time.
  int countInMonth(int year, int month) {
    final normalized = DateTime.utc(year, month);
    final key = normalized.year * 100 + normalized.month;
    return _monthCounts[key] ??= _countMonth(normalized.year, normalized.month);
  }

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

  /// List position of the newest session starting on [day]'s local date, or
  /// null when none did.
  int? firstIndexOn(DateTime day) {
    final from = DateTime.utc(
      day.year,
      day.month,
      day.day - 1,
    ).microsecondsSinceEpoch;
    final to = DateTime.utc(
      day.year,
      day.month,
      day.day + 2,
    ).microsecondsSinceEpoch;
    for (var i = _firstBefore(to); i < _starts.length; i++) {
      final start = _starts[i];
      if (start.microsecondsSinceEpoch < from) break;
      if (start.year == day.year &&
          start.month == day.month &&
          start.day == day.day) {
        return i;
      }
    }
    return null;
  }

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
    final days = <int>{};
    _forMonth(year, month, (start) => days.add(start.day));
    return days;
  }

  int _countMonth(int year, int month) {
    var count = 0;
    _forMonth(year, month, (_) => count++);
    return count;
  }

  /// Calls [visit] with every start in [month], local time.
  void _forMonth(int year, int month, void Function(DateTime start) visit) {
    final from = DateTime.utc(year, month, 0).microsecondsSinceEpoch;
    final to = DateTime.utc(year, month + 1, 2).microsecondsSinceEpoch;
    for (var i = _firstBefore(to); i < _starts.length; i++) {
      final start = _starts[i];
      if (start.microsecondsSinceEpoch < from) break;
      if (start.year == year && start.month == month) visit(start);
    }
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

/// A month laid out in weeks starting on Monday: [days] holds the day of
/// each cell, null for the cells before the 1st and after the last day.
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
