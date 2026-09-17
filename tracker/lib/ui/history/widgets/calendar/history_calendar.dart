import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/routing/tab_navigation.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/ui/history/view_models/calendar_view_model.dart';

import '../session_detail_page.dart';
import '../session_lookup_page.dart';

import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/domain/models/workout_session_summary.dart';

import 'calendar_grid.dart';

/// Interactive month calendar of workout days (Plan.md §2.5).
///
/// [model] lets an owner (e.g. [HistoryPage]) retain navigation and date-index
/// state across this widget's remounts; when omitted, the widget owns a
/// private model with its own lifetime.
class HistoryCalendar extends StatefulWidget {
  const HistoryCalendar({
    super.key,
    this.sessions,
    required this.gymNames,
    this.model,
    this.sliver = false,
  });

  /// Compatibility input for standalone previews/tests, never supplied by History.
  final List<WorkoutSession>? sessions;
  final Map<int, String> gymNames;
  final CalendarViewModel? model;

  /// Join History's viewport. Standalone previews instead own a scroll view.
  final bool sliver;

  @override
  State<HistoryCalendar> createState() => _HistoryCalendarState();
}

class _HistoryCalendarState extends State<HistoryCalendar> {
  static const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const double _reservedHeight = 340;
  static const double _navAllowance = 64;

  CalendarViewModel? _ownedModel;
  bool _openingDetail = false;

  CalendarViewModel get _model => widget.model ?? _ownedModel!;

  @override
  void initState() {
    super.initState();
    if (widget.model == null) _ownedModel = CalendarViewModel();
    _syncWidgetInput();
    _model.addListener(_clockChanged);
  }

  void _clockChanged() => setState(() {});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_model.observeAppLifecycle) {
      _model.setActive(TabVisibilityScope.isActiveOf(context));
    }
  }

  @override
  void didUpdateWidget(covariant HistoryCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.model, oldWidget.model)) {
      final previous = oldWidget.model ?? _ownedModel!;
      previous.removeListener(_clockChanged);
      if (previous.observeAppLifecycle) previous.setActive(false);
      _ownedModel?.dispose();
      _ownedModel = widget.model == null ? CalendarViewModel() : null;
      _model.addListener(_clockChanged);
      if (_model.observeAppLifecycle) {
        _model.setActive(TabVisibilityScope.isActiveOf(context));
      }
    }
    if (!identical(widget.sessions, oldWidget.sessions) ||
        !identical(widget.model, oldWidget.model)) {
      _syncWidgetInput();
    }
  }

  void _syncWidgetInput() {
    final sessions = widget.sessions;
    if (sessions != null) _model.updateSessions(sessions);
  }

  @override
  void dispose() {
    _model.removeListener(_clockChanged);
    if (_model.observeAppLifecycle) _model.setActive(false);
    _ownedModel?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sliver) {
      return SliverLayoutBuilder(
        builder: (context, constraints) => _slivers(
          constraints.viewportMainAxisExtent - kToolbarHeight - _navAllowance,
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => CustomScrollView(
        slivers: [
          _slivers(
            constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : MediaQuery.sizeOf(context).height,
          ),
        ],
      ),
    );
  }

  Widget _slivers(double available) {
    final theme = context.theme;
    final cellHeight =
        ((available - _reservedHeight) / (_model.grid.days.length ~/ 7)).clamp(
          36.0,
          56.0,
        );
    return ValueListenableBuilder<DateTime?>(
      valueListenable: _model.selectedDayListenable,
      builder: (context, selectedDay, _) => SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            // FTabs no longer supplies the Material/text-style ancestor.
            child: Material(
              type: MaterialType.transparency,
              textStyle: theme.typography.body.md.copyWith(
                color: theme.colors.foreground,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_model.datesLoading) const LinearProgressIndicator(),
                  if (_model.datesError != null)
                    Column(
                      children: [
                        const Text(
                          'Could not refresh calendar. Displayed dates may be outdated.',
                        ),
                        TextButton(
                          onPressed: () => setState(_model.retryDates),
                          child: const Text('Retry calendar'),
                        ),
                      ],
                    ),
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
                ],
              ),
            ),
          ),
          _dayList(selectedDay),
        ],
      ),
    );
  }

  Widget _dayList(DateTime? day) {
    if (day == null) {
      return const SliverToBoxAdapter(child: Text('Pick a workout day above.'));
    }
    if (_model.dayLoading) {
      return const SliverToBoxAdapter(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_model.dayError != null) {
      return SliverToBoxAdapter(
        child: Column(
          children: [
            const Text('Could not load this day.'),
            TextButton(
              onPressed: () => setState(_model.retryDay),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final sessions = _model.sessionsOn(day);
    if (sessions.isEmpty) {
      return const SliverToBoxAdapter(child: Text('No workouts on this day.'));
    }
    return SliverList.builder(
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: FItem.raw(
            onPress: () => _openDetail(session),
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
                        Text(plural('set', session.setCount)),
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

  Future<void> _openDetail(WorkoutSessionSummary row) async {
    if (_openingDetail) return;
    _openingDetail = true;
    try {
      final repository = RepositoryScope.maybeOf(context);
      if (repository != null) {
        await pushTo(
          context,
          RepositoryScope(
            repository: repository,
            child: SessionLookupPage(id: row.id, gymNames: widget.gymNames),
          ),
        );
      } else {
        // Standalone fixture adapter: the production widget never has sessions.
        final full = widget.sessions?.where((s) => s.id == row.id).firstOrNull;
        if (full != null) {
          await pushTo(
            context,
            SessionDetailPage(
              session: full,
              gymName: widget.gymNames[full.gymId],
            ),
          );
        }
      }
    } finally {
      _openingDetail = false;
    }
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
    // At most six rows: ordinary boxes avoid a second, shrink-wrapped viewport.
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        children: [
          for (var row = 0; row < grid.days.length ~/ 7; row++) ...[
            if (row > 0) const SizedBox(height: cellSpacing),
            SizedBox(
              height: cellHeight,
              child: Row(
                children: [
                  for (var column = 0; column < 7; column++) ...[
                    if (column > 0) const SizedBox(width: cellSpacing),
                    Expanded(child: _cell(grid.days[row * 7 + column])),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cell(int? dayVal) {
    if (dayVal == null) return const SizedBox.shrink();
    return _DayCell(
      dayVal: dayVal,
      theme: theme,
      isSelected:
          selectedDay != null &&
          selectedDay!.year == grid.year &&
          selectedDay!.month == grid.month &&
          selectedDay!.day == dayVal,
      hasWorkout: daysWithWorkouts.contains(dayVal),
      onTap: () => onSelectDay(DateTime(grid.year, grid.month, dayVal)),
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
