import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/ui/history/view_models/calendar_view_model.dart';

import '../session_detail_page.dart';
import 'calendar_grid.dart';

/// Interactive month calendar of workout days (Plan.md §2.5).
///
/// [model] lets an owner (e.g. [HistoryPage]) retain navigation and date-index
/// state across this widget's remounts; when omitted, the widget owns a
/// private model with its own lifetime.
class HistoryCalendar extends StatefulWidget {
  const HistoryCalendar({
    super.key,
    required this.sessions,
    required this.gymNames,
    this.model,
  });

  final List<WorkoutSession> sessions;
  final Map<int, String> gymNames;
  final CalendarViewModel? model;

  @override
  State<HistoryCalendar> createState() => _HistoryCalendarState();
}

class _HistoryCalendarState extends State<HistoryCalendar> {
  static const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const double _reservedHeight = 340;
  static const double _navAllowance = 64;

  CalendarViewModel? _ownedModel;

  CalendarViewModel get _model => widget.model ?? _ownedModel!;

  @override
  void initState() {
    super.initState();
    if (widget.model == null) _ownedModel = CalendarViewModel();
    _model.updateSessions(widget.sessions);
  }

  @override
  void didUpdateWidget(covariant HistoryCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.model, oldWidget.model)) {
      _ownedModel?.dispose();
      _ownedModel = widget.model == null ? CalendarViewModel() : null;
    }
    _model.updateSessions(widget.sessions);
  }

  @override
  void dispose() {
    _ownedModel?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height -
                  MediaQuery.paddingOf(context).top -
                  kToolbarHeight -
                  _navAllowance;

        final cellHeight =
            ((available - _reservedHeight) / (_model.grid.days.length ~/ 7))
                .clamp(36.0, 56.0);

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _BuildMonthHeader(
                year: _model.year,
                monthName: _monthName(_model.month),
                onPrev: () => setState(() => _model.goMonth(-1)),
                onNext: () => setState(() => _model.goMonth(1)),
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
                valueListenable: _model.selectedDayListenable,
                builder: (context, selectedDay, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DayGrid(
                        grid: _model.grid,
                        theme: theme,
                        cellHeight: cellHeight,
                        selectedDay: selectedDay,
                        daysWithWorkouts: _model.daysWithWorkouts,
                        onSelectDay: _model.selectDay,
                      ),
                      const SizedBox(height: 6),
                      _MetricsStrip(
                        monthWorkoutDays: _model.monthWorkoutDays,
                        streak: _model.streak,
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
          ),
        );
      },
    );
  }

  Widget _dayList(DateTime? day) {
    final sessions = day == null
        ? const <WorkoutSession>[]
        : _model.sessionsOn(day);
    if (day == null) {
      return const Text('Pick a workout day above.');
    }
    if (sessions.isEmpty) {
      return const Text('No workouts on this day.');
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        return Padding(
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
        );
      },
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
    return GridView.builder(
      padding: const EdgeInsets.only(top: 4),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisExtent: cellHeight,
        mainAxisSpacing: cellSpacing,
        crossAxisSpacing: cellSpacing,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: grid.days.length,
      itemBuilder: (context, index) {
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
          isSelected: isSelected,
          hasWorkout: daysWithWorkouts.contains(dayVal),
          onTap: () => onSelectDay(DateTime(grid.year, grid.month, dayVal)),
        );
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.dayVal,
    required this.theme,
    required this.isSelected,
    required this.hasWorkout,
    required this.onTap,
  });

  final int dayVal;
  final FThemeData theme;
  final bool isSelected;
  final bool hasWorkout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected
        ? theme.colors.primaryForeground
        : theme.colors.foreground;
    final dot = isSelected
        ? theme.colors.primaryForeground
        : (hasWorkout ? theme.colors.primary : Colors.transparent);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
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
            Text(
              dayVal.toString(),
              style: theme.typography.body.xs.copyWith(color: foreground),
            ),
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
        IconButton(
          icon: const Icon(FLucideIcons.chevronLeft),
          onPressed: onPrev,
          tooltip: 'Previous month',
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
        IconButton(
          icon: const Icon(FLucideIcons.chevronRight),
          onPressed: onNext,
          tooltip: 'Next month',
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
