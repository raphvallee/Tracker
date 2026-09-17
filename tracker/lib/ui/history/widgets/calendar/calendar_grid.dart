import 'dart:collection';

import 'package:tracker/domain/models/workout_session.dart';

/// Immutable, normalized index of sessions by local calendar date.
///
/// Building this once per session-list update avoids repeatedly scanning all
/// sessions while painting each calendar cell and calculating metrics.
class WorkoutDateIndex {
  factory WorkoutDateIndex.fromSessions(Iterable<WorkoutSession> sessions) {
    final byDay = <DateTime, List<WorkoutSession>>{};
    final instantDays = <DateTime, DateTime>{};
    for (final session in sessions) {
      final instant = session.startTime.toUtc();
      final local = instant.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      instantDays[instant] = day;
      byDay.putIfAbsent(day, () => <WorkoutSession>[]).add(session);
    }
    return WorkoutDateIndex._(byDay, instantDays);
  }

  WorkoutDateIndex._(
    Map<DateTime, List<WorkoutSession>> byDay,
    this._instantDays,
  ) : _byDay = UnmodifiableMapView(<DateTime, List<WorkoutSession>>{
        for (final entry in byDay.entries)
          entry.key: UnmodifiableListView(entry.value),
      }),
      workoutDays = UnmodifiableSetView(byDay.keys.toSet()) {
    final counts = <int, int>{};
    for (final day in byDay.keys) {
      final key = day.year * 100 + day.month;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    _monthCounts = UnmodifiableMapView(counts);
  }

  late final Map<int, int> _monthCounts;

  final Map<DateTime, List<WorkoutSession>> _byDay;
  final Set<DateTime> workoutDays;
  final Map<DateTime, DateTime> _instantDays;

  /// Validate actual cached dates on resume, not an ambiguous zone abbreviation.
  bool get matchesLocalTimezone => _instantDays.entries.every((entry) {
    final local = entry.key.toLocal();
    return DateTime(local.year, local.month, local.day) == entry.value;
  });

  List<WorkoutSession> sessionsOn(DateTime day) => _byDay[day] ?? const [];

  int monthWorkoutDays(int year, int month) =>
      _monthCounts[year * 100 + month] ?? 0;
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

/// Consecutive local workout dates ending today, or yesterday if today is empty.
/// [workoutDays] contains local midnights; [today] is explicit so this is pure.
int currentStreak(Set<DateTime> workoutDays, DateTime today) {
  final local = today.toLocal();
  var day = DateTime(local.year, local.month, local.day);
  if (!workoutDays.contains(day)) {
    day = DateTime(day.year, day.month, day.day - 1);
  }
  var streak = 0;
  while (workoutDays.contains(day)) {
    streak++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return streak;
}
