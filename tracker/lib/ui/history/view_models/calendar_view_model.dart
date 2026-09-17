import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/ui/history/widgets/calendar/calendar_grid.dart';

/// Calendar presentation state, owned by History rather than its disposable tab.
///
/// Session delivery invalidates lazy data without notifying during parent builds.
/// Clock notifications are independent: midnight never scans unchanged sessions.
class CalendarViewModel extends ChangeNotifier {
  CalendarViewModel({DateTime? initialDate, DateTime Function()? now})
    : _now = now ?? DateTime.now {
    final clock = _now().toLocal();
    _today = DateTime(clock.year, clock.month, clock.day);
    final day = (initialDate ?? clock).toLocal();
    _year = day.year;
    _month = day.month;
    _selectedDay = ValueNotifier(DateTime(day.year, day.month, day.day));
  }

  final DateTime Function() _now;
  List<WorkoutSession> _sessions = const [];
  WorkoutDateIndex? _dateIndex;
  CalendarGrid? _grid;
  Set<int>? _daysWithWorkouts;
  late int _year;
  late int _month;
  late DateTime _today;
  late final ValueNotifier<DateTime?> _selectedDay;
  Timer? _midnightTimer;
  AppLifecycleListener? _lifecycleListener;
  bool _active = false;
  bool _appVisible = true;

  int get year => _year;
  int get month => _month;
  DateTime get today => _today;
  DateTime? get selectedDay => _selectedDay.value;
  ValueListenable<DateTime?> get selectedDayListenable => _selectedDay;

  WorkoutDateIndex get dateIndex =>
      _dateIndex ??= WorkoutDateIndex.fromSessions(_sessions);

  CalendarGrid get grid => _grid ??= CalendarGrid(_year, _month);
  int get monthWorkoutDays => dateIndex.monthWorkoutDays(_year, _month);
  int get streak => currentStreak(dateIndex.workoutDays, _today);
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

  /// Called by the mounted calendar with its top-level tab visibility.
  /// Activation refreshes synchronously; the caller is already rebuilding.
  void setActive(bool active) {
    if (_active == active) return;
    _active = active;
    if (!active) {
      _midnightTimer?.cancel();
      _midnightTimer = null;
      _lifecycleListener?.dispose();
      _lifecycleListener = null;
      return;
    }
    final state = WidgetsBinding.instance.lifecycleState;
    _appVisible =
        state != AppLifecycleState.hidden && state != AppLifecycleState.paused;
    _lifecycleListener = AppLifecycleListener(
      onStateChange: (state) {
        if (state == AppLifecycleState.resumed) {
          _appVisible = true;
          refreshClock();
        } else if (state == AppLifecycleState.hidden ||
            state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached) {
          _appVisible = false;
          _midnightTimer?.cancel();
          _midnightTimer = null;
        }
      },
    );
    _refreshClock(notify: false, checkTimezone: true);
  }

  /// Revalidate cached date mappings after suspension; midnight skips this scan.
  void refreshClock() => _refreshClock(notify: true, checkTimezone: true);

  void _refreshClock({required bool notify, bool checkTimezone = false}) {
    final clock = _now().toUtc().toLocal();
    final day = DateTime(clock.year, clock.month, clock.day);
    final zoneChanged =
        checkTimezone &&
        _dateIndex != null &&
        !_dateIndex!.matchesLocalTimezone;
    final changed = day != _today || zoneChanged;
    _today = day;
    if (zoneChanged) {
      // Retained source instants are regrouped lazily before the next read.
      _dateIndex = null;
      _daysWithWorkouts = null;
      final selected = _selectedDay.value;
      if (selected != null) {
        // Preserve the selected calendar date, not its old-zone instant.
        _selectedDay.value = DateTime(_year, _month, selected.day);
      }
    }
    _midnightTimer?.cancel();
    _midnightTimer = null;
    if (_active && _appVisible) {
      final midnight = DateTime(clock.year, clock.month, clock.day + 1);
      _midnightTimer = Timer(
        midnight.difference(clock),
        () => _refreshClock(notify: true),
      );
    }
    if (changed && notify) notifyListeners();
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

  @override
  void dispose() {
    setActive(false);
    _selectedDay.dispose();
    super.dispose();
  }
}
