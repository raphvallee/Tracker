import 'package:flutter/foundation.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/ui/history/widgets/calendar/calendar_grid.dart';

/// Calendar presentation state, owned by History rather than its disposable tab.
///
/// Session snapshots are replaced by identity, matching the existing delivery
/// contract. Updating a snapshot only invalidates derived data; it neither scans
/// sessions nor notifies listeners during a parent build. The calendar reads the
/// lazy caches when mounted. Navigation survives data and tab-body replacement.
class CalendarViewModel {
  CalendarViewModel({DateTime? initialDate}) {
    final day = initialDate ?? DateTime.now();
    _year = day.year;
    _month = day.month;
    _selectedDay = ValueNotifier(DateTime(day.year, day.month, day.day));
  }

  List<WorkoutSession> _sessions = const [];
  WorkoutDateIndex? _dateIndex;
  CalendarGrid? _grid;
  Set<int>? _daysWithWorkouts;
  late int _year;
  late int _month;
  late final ValueNotifier<DateTime?> _selectedDay;

  int get year => _year;
  int get month => _month;
  DateTime? get selectedDay => _selectedDay.value;
  ValueListenable<DateTime?> get selectedDayListenable => _selectedDay;

  WorkoutDateIndex get dateIndex =>
      _dateIndex ??= WorkoutDateIndex.fromSessions(_sessions);
  CalendarGrid get grid => _grid ??= CalendarGrid(_year, _month);
  int get monthWorkoutDays => dateIndex.monthWorkoutDays(_year, _month);
  int get streak => dateIndex.currentStreak();
  Set<int> get daysWithWorkouts => _daysWithWorkouts ??= Set.unmodifiable({
    for (final day in grid.days)
      if (day != null &&
          dateIndex.sessionsOn(DateTime(_year, _month, day)).isNotEmpty)
        day,
  });

  void updateSessions(List<WorkoutSession> sessions) {
    if (identical(sessions, _sessions)) return;
    _sessions = sessions;
    _dateIndex = null;
    _daysWithWorkouts = null;
  }

  List<WorkoutSession> sessionsOn(DateTime day) => dateIndex.sessionsOn(day);

  void selectDay(DateTime day) => _selectedDay.value = day;

  /// The caller rebuilds the month header/grid; selection has its own listener.
  void goMonth(int delta) {
    final date = DateTime(_year, _month + delta);
    _year = date.year;
    _month = date.month;
    _grid = null;
    _daysWithWorkouts = null;
    _selectedDay.value = null;
  }

  void dispose() => _selectedDay.dispose();
}
