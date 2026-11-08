import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/routing/tab_navigation.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/core/ui/icon_button.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';

import '../session_detail_page.dart';
import 'calendar_grid.dart';

/// Month calendar of the workout history.
///
/// Lays out at its content height, so it belongs in a scrollable (the History
/// page puts it in a sliver).
class HistoryCalendar extends StatefulWidget {
  const HistoryCalendar({
    super.key,
    required this.index,
    required this.sessionsOn,
    required this.gymNames,
  });

  /// Workout days of the whole history.
  final WorkoutDateIndex index;

  /// Sessions starting on the given local day, newest first. Only called for
  /// the selected day, again whenever [index] changes.
  final List<WorkoutSession> Function(DateTime day) sessionsOn;

  final Map<int, String> gymNames;

  @override
  State<HistoryCalendar> createState() => _HistoryCalendarState();
}

class _HistoryCalendarState extends State<HistoryCalendar> {
  static const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const double _reservedHeight = 340;
  static const double _navAllowance = 64;

  late int _year;
  late int _month;
  late DateTime _today;
  late final ValueNotifier<DateTime?> _selectedDayNotifier;
  bool? _wasActive;

  late CalendarGrid _grid;
  late Set<int> _daysWithWorkouts;
  late int _streak;

  DateTime? _listedDay;
  WorkoutDateIndex? _listedIndex;
  List<WorkoutSession> _listed = const [];

  @override
  void initState() {
    super.initState();
    _today = _day(DateTime.now());
    _year = _today.year;
    _month = _today.month;
    _selectedDayNotifier = ValueNotifier(_today);

    _streak = widget.index.currentStreak();
    _updateMonthData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The tab shell builds History ahead of time, so the calendar can stay
    // mounted across midnight: re-resolve "today" whenever its tab shows.
    final active = TabVisibilityScope.isActiveOf(context);
    if (active && _wasActive == false) _refreshToday();
    _wasActive = active;
  }

  @override
  void didUpdateWidget(covariant HistoryCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.index, widget.index)) {
      _streak = widget.index.currentStreak();
      _updateMonthData();
    }
  }

  @override
  void dispose() {
    _selectedDayNotifier.dispose();
    super.dispose();
  }

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

  void _refreshToday() {
    final today = _day(DateTime.now());
    if (today == _today) return;
    // Follow the date only if the user had not moved off "today".
    final onToday =
        _selectedDayNotifier.value == _today &&
        _year == _today.year &&
        _month == _today.month;
    _today = today;
    _streak = widget.index.currentStreak();
    if (onToday) {
      _year = today.year;
      _month = today.month;
      _selectedDayNotifier.value = today;
      _updateMonthData();
    }
  }

  List<WorkoutSession> _sessionsOn(DateTime day) {
    if (day != _listedDay || !identical(_listedIndex, widget.index)) {
      _listedDay = day;
      _listedIndex = widget.index;
      _listed = widget.sessionsOn(day);
    }
    return _listed;
  }

  void _updateMonthData() {
    _grid = CalendarGrid(_year, _month);
    _daysWithWorkouts = widget.index.workoutDaysIn(_year, _month);
  }

  void _goMonth(int delta) {
    setState(() {
      final d = DateTime(_year, _month + delta);
      _year = d.year;
      _month = d.month;
      _selectedDayNotifier.value = null;
      _updateMonthData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    // The calendar always sits in a scrollable (unbounded height), so size the
    // cells from the window instead of the incoming constraints.
    final available =
        MediaQuery.sizeOf(context).height -
        MediaQuery.paddingOf(context).top -
        kToolbarHeight -
        _navAllowance;
    final cellHeight =
        ((available - _reservedHeight) / (_grid.days.length ~/ 7)).clamp(
          36.0,
          56.0,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _BuildMonthHeader(
          year: _year,
          monthName: _monthName(_month),
          onPrev: () => _goMonth(-1),
          onNext: () => _goMonth(1),
        ),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            for (final label in _weekdayLabels)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: theme.typography.body.xs.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        ValueListenableBuilder<DateTime?>(
          valueListenable: _selectedDayNotifier,
          builder: (context, selectedDay, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DayGrid(
                  grid: _grid,
                  theme: theme,
                  cellHeight: cellHeight,
                  selectedDay: selectedDay,
                  daysWithWorkouts: _daysWithWorkouts,
                  onSelectDay: (day) => _selectedDayNotifier.value = day,
                ),
                const SizedBox(height: 6),
                _MetricsStrip(
                  monthWorkoutDays: _daysWithWorkouts.length,
                  streak: _streak,
                ),
                const SizedBox(height: 6),
                Text(
                  selectedDay == null
                      ? 'Workouts'
                      : 'Workouts · ${_dateLabel(selectedDay)}',
                  style: theme.typography.body.sm.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                _dayList(selectedDay),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _dayList(DateTime? day) {
    if (day == null) {
      return const Text('Pick a workout day above.');
    }
    final sessions = _sessionsOn(day);
    if (sessions.isEmpty) {
      return const Text('No workouts on this day.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final session in sessions)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: FItem.raw(
              onPress: () => pushTo(
                context,
                SessionDetailPage(
                  session: session,
                  gymName: session.gymId == null
                      ? null
                      : widget.gymNames[session.gymId],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(FLucideIcons.footprints),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(session.title),
                          Text(plural('set', session.sets.length)),
                        ],
                      ),
                    ),
                    const Icon(FLucideIcons.chevronRight),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _monthName(int m) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return names[m - 1];
  }

  String _dateLabel(DateTime d) => '${d.year}-${_p(d.month)}-${_p(d.day)}';

  String _p(int v) => v.toString().padLeft(2, '0');
}

class _DayGrid extends StatelessWidget {
  const _DayGrid({
    required this.grid,
    required this.theme,
    required this.cellHeight,
    required this.selectedDay,
    required this.daysWithWorkouts,
    required this.onSelectDay,
  });

  final CalendarGrid grid;
  final FThemeData theme;
  final double cellHeight;
  final DateTime? selectedDay;
  final Set<int> daysWithWorkouts;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    const double cellSpacing = 4;
    final rowCount = grid.days.length ~/ 7;
    final dayStyle = theme.typography.body.xs;
    final styles = (
      normal: dayStyle.copyWith(color: theme.colors.foreground),
      selected: dayStyle.copyWith(color: theme.colors.primaryForeground),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var row = 0; row < rowCount; row++) ...[
            if (row > 0) const SizedBox(height: cellSpacing),
            Row(
              children: <Widget>[
                for (var column = 0; column < 7; column++) ...[
                  if (column > 0) const SizedBox(width: cellSpacing),
                  Expanded(
                    child: SizedBox(
                      height: cellHeight,
                      child: _cellAt(row * 7 + column, styles),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _cellAt(int index, ({TextStyle normal, TextStyle selected}) styles) {
    final dayVal = grid.days[index];
    if (dayVal == null) return const SizedBox.shrink();

    final isSelected =
        selectedDay != null &&
        selectedDay!.year == grid.year &&
        selectedDay!.month == grid.month &&
        selectedDay!.day == dayVal;

    return _DayCell(
      dayVal: dayVal,
      theme: theme,
      textStyle: isSelected ? styles.selected : styles.normal,
      isSelected: isSelected,
      hasWorkout: daysWithWorkouts.contains(dayVal),
      onTap: () => onSelectDay(DateTime(grid.year, grid.month, dayVal)),
    );
  }
}

/// A plain gesture target: an InkWell per cell built a Focus, Actions,
/// MouseRegion and ink layer for each of the 42 cells, which dominated the
/// grid's mount cost.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.dayVal,
    required this.theme,
    required this.textStyle,
    required this.isSelected,
    required this.hasWorkout,
    required this.onTap,
  });

  final int dayVal;
  final FThemeData theme;
  final TextStyle textStyle;
  final bool isSelected;
  final bool hasWorkout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dot = isSelected
        ? theme.colors.primaryForeground
        : (hasWorkout ? theme.colors.primary : Colors.transparent);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: isSelected ? theme.colors.primary : null,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(dayVal.toString(), style: textStyle),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuildMonthHeader extends StatelessWidget {
  const _BuildMonthHeader({
    required this.year,
    required this.monthName,
    required this.onPrev,
    required this.onNext,
  });

  final int year;
  final String monthName;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Row(
      children: <Widget>[
        AppIconButton(
          icon: FLucideIcons.chevronLeft,
          tooltip: 'Previous month',
          onPress: onPrev,
        ),
        Expanded(
          child: Text(
            '$monthName $year',
            textAlign: TextAlign.center,
            style: theme.typography.body.md.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        AppIconButton(
          icon: FLucideIcons.chevronRight,
          tooltip: 'Next month',
          onPress: onNext,
        ),
      ],
    );
  }
}

class _MetricsStrip extends StatelessWidget {
  const _MetricsStrip({required this.monthWorkoutDays, required this.streak});

  final int monthWorkoutDays;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _Metric(label: 'workout days', value: '$monthWorkoutDays'),
        _Metric(label: 'day streak', value: '$streak'),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return FCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              value,
              style: theme.typography.body.sm.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
