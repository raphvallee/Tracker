import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:tracker/data/repositories/workout_session_repository.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_session_summary.dart';
import 'package:tracker/ui/history/widgets/calendar/calendar_grid.dart';

/// Calendar presentation state, owned by History rather than its disposable tab.
///
/// Session delivery invalidates lazy data without notifying during parent builds.
/// Clock notifications are independent: midnight never scans unchanged sessions.
class CalendarViewModel extends ChangeNotifier {
  CalendarViewModel({
    DateTime? initialDate,
    DateTime Function()? now,
    this.observeAppLifecycle = true,
  }) : _now = now ?? DateTime.now {
    final clock = _now().toLocal();
    _today = DateTime(clock.year, clock.month, clock.day);
    final day = (initialDate ?? clock).toLocal();
    _year = day.year;
    _month = day.month;
    _selectedDay = ValueNotifier(DateTime(day.year, day.month, day.day));
  }

  /// HistoryPage owns app lifecycle for both modes; standalone calendars may
  /// still own their clock listener through setActive.
  final bool observeAppLifecycle;
  final DateTime Function() _now;
  bool _historyActive = true;
  bool get _queriesActive => _historyActive && _calendarMode;
  List<DateTime> _dates = const [];
  WorkoutDateProjection? _projection;
  // Standalone widget adapter only. Production binds the scoped repository.
  List<WorkoutSessionSummary> _standaloneRows = const [];
  WorkoutSessionRepository? _repository;
  bool _calendarMode = false;
  StreamSubscription<List<DateTime>>? _dateSubscription;
  StreamSubscription<List<WorkoutSessionSummary>>? _daySubscription;
  int _dateGeneration = 0;
  int _dayGeneration = 0;
  bool datesLoading = false;
  Object? datesError;
  bool dayLoading = false;
  Object? dayError;
  List<WorkoutSessionSummary> dayRows = const [];
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
      _dateIndex ??= WorkoutDateIndex.fromProjection(
        _projection ??= WorkoutDateProjection(_dates),
      );

  CalendarGrid get grid => _grid ??= CalendarGrid(_year, _month);
  int get monthWorkoutDays => dateIndex.monthWorkoutDays(_year, _month);
  int get streak => currentStreak(dateIndex.workoutDays, _today);
  Set<int> get daysWithWorkouts => _daysWithWorkouts ??= Set.unmodifiable({
    for (final day in grid.days)
      if (day != null && dateIndex.countOn(DateTime(_year, _month, day)) > 0)
        day,
  });

  /// Returns whether semantic date counts changed, without notifying during a
  /// parent build. Occupied-day/month index construction stays lazy.
  bool updateDates(Iterable<DateTime> dates) {
    _dates = List.unmodifiable(dates);
    final previous = _projection;
    final next = WorkoutDateProjection(_dates);
    // Always retain current instant mappings, even for equal date counts.
    _projection = next;
    if (previous != null && mapEquals(previous.dateCounts, next.dateCounts)) {
      return false;
    }
    _dateIndex = null;
    _daysWithWorkouts = null;
    return true;
  }

  /// Adapter for standalone calendars; never retains full session objects.
  void updateSessions(List<WorkoutSession> sessions) {
    _standaloneRows = List.unmodifiable(
      sessions.map(WorkoutSessionSummary.fromSession),
    );
    updateDates(_standaloneRows.map((row) => row.startTime));
  }

  void bindRepository(WorkoutSessionRepository? repository) {
    if (identical(repository, _repository)) return;
    _cancelDates();
    _cancelDay();
    _repository = repository;
    _projection = null;
    updateDates(const []);
    _standaloneRows = const [];
    datesError = null;
    if (_queriesActive) _startCalendar();
  }

  /// Effective History visibility (top-level tab AND app), supplied by its
  /// owner. Invalidate generations before cancelling native work already begun.
  void setHistoryActive(bool active) {
    if (_historyActive == active) return;
    _historyActive = active;
    if (!active) {
      _cancelDates();
      _cancelDay();
      setActive(false);
    } else if (_calendarMode) {
      if (!observeAppLifecycle) setActive(true);
      _startCalendar();
    }
  }

  void setCalendarMode(bool enabled) {
    if (_calendarMode == enabled) return;
    _calendarMode = enabled;
    if (_queriesActive) {
      if (!observeAppLifecycle) setActive(true);
      _startCalendar();
    } else {
      _cancelDates();
      _cancelDay();
      setActive(false);
    }
  }

  void _startCalendar() {
    retryDates();
    retryDay();
  }

  void _cancelDates() {
    _dateGeneration++;
    unawaited(_dateSubscription?.cancel());
    _dateSubscription = null;
    datesLoading = false;
  }

  void _cancelDay() {
    _dayGeneration++;
    unawaited(_daySubscription?.cancel());
    _daySubscription = null;
    dayRows = const [];
    dayLoading = false;
    dayError = null;
  }

  void retryDates() {
    _cancelDates();
    final repository = _repository;
    if (!_queriesActive || repository == null) return;
    final generation = _dateGeneration;
    bool current() =>
        generation == _dateGeneration &&
        identical(repository, _repository) &&
        _queriesActive;
    datesLoading = true;
    datesError = null;
    _dateSubscription = repository.watchStartTimes().listen(
      (dates) {
        if (!current()) return;
        final changed = updateDates(dates);
        final statusChanged = datesLoading || datesError != null;
        datesLoading = false;
        datesError = null;
        if (changed || statusChanged) notifyListeners();
      },
      onError: (Object error) {
        if (!current()) return;
        datesLoading = false;
        datesError = error;
        notifyListeners();
      },
    );
  }

  void retryDay() {
    _cancelDay();
    final repository = _repository;
    final day = selectedDay;
    if (!_queriesActive || repository == null || day == null) return;
    final generation = _dayGeneration;
    bool current() =>
        generation == _dayGeneration &&
        identical(repository, _repository) &&
        _queriesActive;
    dayLoading = true;
    _daySubscription = repository
        .watchSummariesForDate(day)
        .listen(
          (rows) {
            if (!current()) return;
            final changed = !listEquals(dayRows, rows);
            final statusChanged = dayLoading || dayError != null;
            if (changed) dayRows = List.unmodifiable(rows);
            dayLoading = false;
            dayError = null;
            if (changed || statusChanged) notifyListeners();
          },
          onError: (Object error) {
            if (!current()) return;
            dayLoading = false;
            dayError = error;
            notifyListeners();
          },
        );
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
    if (!observeAppLifecycle) {
      _appVisible = true;
      _refreshClock(notify: false, checkTimezone: true, refreshDay: false);
      return;
    }
    final state = WidgetsBinding.instance.lifecycleState;
    _appVisible =
        state != AppLifecycleState.hidden &&
        state != AppLifecycleState.paused &&
        state != AppLifecycleState.detached;
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

  void _refreshClock({
    required bool notify,
    bool checkTimezone = false,
    bool refreshDay = true,
  }) {
    final clock = _now().toUtc().toLocal();
    final day = DateTime(clock.year, clock.month, clock.day);
    final zoneChanged =
        checkTimezone &&
        _projection != null &&
        !_projection!.matchesLocalTimezone;
    final changed = day != _today || zoneChanged;
    _today = day;
    if (zoneChanged) {
      // Regroup the latest raw instants; date/month derivations stay lazy.
      updateDates(_dates);
      final selected = _selectedDay.value;
      if (selected != null) {
        // Preserve the selected calendar date, not its old-zone instant.
        _selectedDay.value = DateTime(_year, _month, selected.day);
        if (refreshDay) retryDay();
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

  List<WorkoutSessionSummary> sessionsOn(DateTime day) {
    if (_repository != null) return day == selectedDay ? dayRows : const [];
    return List.unmodifiable(
      _standaloneRows.where((row) {
        final local = row.startTime.toUtc().toLocal();
        return DateTime(local.year, local.month, local.day) == day;
      }),
    );
  }

  void selectDay(DateTime day) {
    if (day == selectedDay) return;
    _selectedDay.value = day;
    retryDay();
    notifyListeners();
  }

  /// The caller rebuilds the month header/grid; selection has its own listener.
  void goMonth(int delta) {
    final date = DateTime(_year, _month + delta);
    _year = date.year;
    _month = date.month;
    _grid = null;
    _daysWithWorkouts = null;
    _selectedDay.value = null;
    _cancelDay();
  }

  @override
  void dispose() {
    _cancelDates();
    _cancelDay();
    setActive(false);
    _selectedDay.dispose();
    super.dispose();
  }
}
