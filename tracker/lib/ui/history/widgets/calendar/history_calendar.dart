import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/domain/services/workout_dates.dart';
import 'package:tracker/ui/core/ui/max_width.dart';
import 'package:tracker/ui/core/ui/relative_dates.dart';
import 'package:tracker/ui/core/ui/sheet_surface.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';

/// The History calendar in a sheet: a month at a time, its workout days
/// filled in. Resolves to the workout day tapped, or null when the sheet
/// closes without one.
Future<DateTime?> showHistoryCalendar(
  BuildContext context, {
  required WorkoutDateIndex index,
}) {
  return showFSheet<DateTime>(
    context: context,
    side: .btt,
    useRootNavigator: true,
    mainAxisMaxRatio: 0.9,
    builder: (sheetContext) => SheetSurface(
      scrollable: true,
      child: MaxWidth(
        max: 440,
        child: HistoryCalendar(
          index: index,
          onPickDay: (day) => Navigator.of(sheetContext).pop(day),
        ),
      ),
    ),
  );
}

/// One month of the workout history: workout days filled in ink, today
/// ringed, the month's workout days next to its name and the current streak
/// under it. Only a workout day takes a tap.
class HistoryCalendar extends StatefulWidget {
  const HistoryCalendar({
    super.key,
    required this.index,
    required this.onPickDay,
  });

  /// Workout days of the whole history.
  final WorkoutDateIndex index;

  /// Told the day of a workout day tapped.
  final ValueChanged<DateTime> onPickDay;

  @override
  State<HistoryCalendar> createState() => _HistoryCalendarState();
}

class _HistoryCalendarState extends State<HistoryCalendar> {
  static const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  /// The page of today's month. The months are pages of a carousel that runs
  /// both ways from it, each one made only when it comes into view.
  static const int _todayPage = 10000;

  /// Each page is this much wider than the carousel, the extra a gap on both
  /// sides of its month: the months sit apart while one is dragged away.
  static const double _pageFraction = 1.07;

  /// The rows of a page above its grid: the month's name, then the days of
  /// the week, each with the space under it.
  static const double _titleHeight = 44;
  static const double _weekdaysHeight = 18;
  static const double _pageHeight =
      _titleHeight + 8 + _weekdaysHeight + 6 + _DayGrid.height;

  late final DateTime _today;
  late final PageController _pages;
  int _page = _todayPage;

  /// Which way the carousel last turned: 1 forward, -1 back.
  int _direction = 1;

  /// The months made so far: the one shown and the ones next to it. Anything
  /// further away is dropped when the carousel settles on a month.
  final Map<int, _Month> _months = {};
  int _prefetchRun = 0;
  late int _streak;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _pages = PageController(
      initialPage: _todayPage,
      viewportFraction: _pageFraction,
    );
    _streak = widget.index.currentStreak();
    _prefetch();
  }

  @override
  void didUpdateWidget(covariant HistoryCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.index, widget.index)) return;
    _streak = widget.index.currentStreak();
    _months.clear();
    _prefetch();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  DateTime _monthOf(int page) =>
      DateTime(_today.year, _today.month + page - _todayPage);

  /// The month on [page]: made when it is first asked for.
  _Month _monthAt(int page) => _months.putIfAbsent(page, () {
    final month = _monthOf(page);
    return _Month(
      grid: CalendarGrid(month.year, month.month),
      workoutDays: widget.index.workoutDaysIn(month.year, month.month),
    );
  });

  void _onPageChanged(int page) {
    setState(() {
      _direction = page > _page ? 1 : -1;
      _page = page;
    });
    _prefetch();
  }

  /// Keeps the month shown and the two next to it, and nothing else: the one
  /// the carousel is heading to is made first, the one behind after it, each
  /// in a task of its own so no frame carries both.
  Future<void> _prefetch() async {
    final run = ++_prefetchRun;
    _months.removeWhere((page, _) => (page - _page).abs() > 1);
    _monthAt(_page);
    for (final page in [_page + _direction, _page - _direction]) {
      if (_months.containsKey(page)) continue;
      await Future<void>.delayed(Duration.zero);
      if (!mounted || run != _prefetchRun) return;
      _monthAt(page);
    }
  }

  /// Back to the month of today. From far away it lands next to it first,
  /// so a long way back is one slide, not every month on the way.
  void _goToday() {
    final distance = _page - _todayPage;
    if (distance == 0) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(_todayPage);
      return;
    }
    if (distance.abs() > 1) _pages.jumpToPage(_todayPage + distance.sign);
    _pages.animateToPage(
      _todayPage,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  String get _streakLabel =>
      _streak == 0 ? 'No streak right now' : '$_streak-day streak';

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Each page of the carousel is a whole month: its name and workout
        // days, the days of the week and its grid, so all of it moves
        // together. What belongs to no one month stays still under it.
        SizedBox(
          height: _pageHeight,
          child: PageView.builder(
            controller: _pages,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, page) => _monthPage(context, page),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: _BackToThisMonth.height,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _streakLabel,
                  style: theme.typography.body.xs.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
              ),
              _BackToThisMonth(
                key: const ValueKey('this-month'),
                pages: _pages,
                todayPage: _todayPage,
                onPress: _goToday,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// One page: the month's name and workout days, the days of the week and
  /// its grid. The
  /// month fills the carousel's width and the page's extra width is the gap
  /// around it. A line on the page's own edge, in the middle of that gap,
  /// shows between two months mid swipe, and never at rest, where the
  /// viewport clips it.
  Widget _monthPage(BuildContext context, int page) {
    final theme = context.theme;
    final muted = theme.colors.mutedForeground;
    final month = _monthAt(page);
    final date = _monthOf(page);
    final workoutDays = month.workoutDays.length;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(
          child: FractionallySizedBox(
            widthFactor: 1 / _pageFraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  height: _titleHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      Text(
                        '${monthName(date.month)} ${date.year}',
                        maxLines: 1,
                        style: theme.typography.body.lg.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          workoutDays == 0
                              ? 'No workout days'
                              : plural('workout day', workoutDays),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.body.xs.copyWith(
                            color: muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: _weekdaysHeight,
                  child: Row(
                    children: <Widget>[
                      for (final (i, label) in _weekdayLabels.indexed) ...[
                        if (i > 0) const SizedBox(width: _DayGrid.gap),
                        Expanded(
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: theme.typography.body.xs.copyWith(
                              color: muted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                _DayGrid(
                  grid: month.grid,
                  today: _today,
                  workoutDays: month.workoutDays,
                  onPickDay: widget.onPickDay,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: -1,
          top: 0,
          bottom: 0,
          width: 1,
          child: ColoredBox(color: muted.withValues(alpha: 0.35)),
        ),
      ],
    );
  }
}

/// The way back to this month, under the carousel next to the streak. It
/// follows the carousel frame by frame instead of running on a timer: it
/// shows as much as the month on screen has moved away from this one, so
/// dragging out of this month brings it in and dragging back takes it away.
/// Its arrow is on the side of this month and points to it. Until it is
/// more than half in, it takes no taps, focus or semantics.
class _BackToThisMonth extends StatelessWidget {
  const _BackToThisMonth({
    super.key,
    required this.pages,
    required this.todayPage,
    required this.onPress,
  });

  /// The room it takes, out or not, so the streak never moves.
  static const double height = 36;

  final PageController pages;
  final int todayPage;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pages,
      builder: (context, _) {
        final page = pages.hasClients && pages.position.haveDimensions
            ? pages.page!
            : todayPage.toDouble();
        final away = page - todayPage;
        final shown = away.abs().clamp(0.0, 1.0);
        final active = shown > 0.5;
        // Past this month, it is back to the left; before it, to the right.
        final backLeft = away > 0;
        return ExcludeFocus(
          excluding: !active,
          child: IgnorePointer(
            ignoring: !active,
            child: ExcludeSemantics(
              excluding: !active,
              child: Opacity(
                opacity: shown,
                child: Transform.scale(
                  scale: 0.92 + 0.08 * shown,
                  child: Semantics(
                    button: true,
                    excludeSemantics: true,
                    label: 'This month',
                    onTap: onPress,
                    child: FButton(
                      variant: .outline,
                      size: .sm,
                      mainAxisSize: .min,
                      onPress: onPress,
                      prefix: backLeft
                          ? const Icon(FLucideIcons.chevronLeft)
                          : null,
                      suffix: backLeft
                          ? null
                          : const Icon(FLucideIcons.chevronRight),
                      child: const Icon(FLucideIcons.calendarCheck),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A month of the carousel: its grid and the days a workout started on.
class _Month {
  const _Month({required this.grid, required this.workoutDays});

  final CalendarGrid grid;
  final Set<int> workoutDays;
}

class _DayGrid extends StatelessWidget {
  const _DayGrid({
    required this.grid,
    required this.today,
    required this.workoutDays,
    required this.onPickDay,
  });

  static const double gap = 4;
  static const double cellHeight = 38;

  /// The most weeks a month can span: every month is laid out in this many
  /// rows, the ones after its last day left empty.
  static const int maxRows = 6;

  static const double height = maxRows * cellHeight + (maxRows - 1) * gap;

  final CalendarGrid grid;
  final DateTime today;
  final Set<int> workoutDays;
  final ValueChanged<DateTime> onPickDay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var row = 0; row < maxRows; row++) ...[
          if (row > 0) const SizedBox(height: gap),
          Row(
            children: <Widget>[
              for (var column = 0; column < 7; column++) ...[
                if (column > 0) const SizedBox(width: gap),
                Expanded(
                  child: SizedBox(
                    height: cellHeight,
                    child: _cellAt(context, row * 7 + column),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _cellAt(BuildContext context, int index) {
    final day = index < grid.days.length ? grid.days[index] : null;
    if (day == null) return const SizedBox.shrink();
    final date = DateTime(grid.year, grid.month, day);
    final hasWorkout = workoutDays.contains(day);
    return _DayCell(
      day: day,
      date: date,
      hasWorkout: hasWorkout,
      isToday: date == today,
      isFuture: date.isAfter(today),
      onTap: hasWorkout ? () => onPickDay(date) : null,
    );
  }
}

/// A plain gesture target: an InkWell per cell built a Focus, Actions,
/// MouseRegion and ink layer for each of the 42 cells, which dominated the
/// grid's mount cost.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.date,
    required this.hasWorkout,
    required this.isToday,
    required this.isFuture,
    required this.onTap,
  });

  final int day;
  final DateTime date;
  final bool hasWorkout;
  final bool isToday;
  final bool isFuture;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = theme.colors;
    final Color text;
    if (hasWorkout) {
      text = colors.background;
    } else if (isFuture) {
      text = colors.mutedForeground.withValues(alpha: 0.45);
    } else {
      text = colors.foreground;
    }
    final cell = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hasWorkout ? colors.foreground : null,
        borderRadius: BorderRadius.circular(8),
        border: isToday
            ? Border.all(color: colors.mutedForeground, width: 1.5)
            : null,
      ),
      child: Text(
        '$day',
        style: theme.typography.body.xs.copyWith(
          color: text,
          fontWeight: hasWorkout ? FontWeight.w700 : FontWeight.w400,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    if (onTap == null) return cell;
    return Semantics(
      button: true,
      label: 'Workout on ${shortDateLabel(date)}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: cell,
      ),
    );
  }
}
