import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/data/services/app_log.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/services/session_summary.dart';
import 'package:tracker/domain/services/workout_dates.dart';
import 'package:tracker/routing/tab_navigation.dart';
import 'package:tracker/ui/core/ui/animated_reveal.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/core/ui/icon_button.dart';
import 'package:tracker/ui/core/ui/max_width.dart';
import 'package:tracker/ui/core/ui/relative_dates.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

import 'calendar/history_calendar.dart';
import 'restore_strip.dart';
import 'session_detail_page.dart';

/// Every finished workout, newest first, under its month. Rows are built
/// and read lazily: the first frame reads the ids and start times only, and
/// a page of sessions is read when its first row is built, so a long
/// history costs no more to open than a short one.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  static const _pageSize = 24;

  TrackerRepository? _repo;
  StreamSubscription<void>? _changes;
  bool _didLoad = false;
  bool _active = true;
  bool _stale = false;
  Object? _error;

  Map<int, String> _gymNames = const {};
  List<int> _ids = const [];
  WorkoutDateIndex _index = WorkoutDateIndex(const []);

  /// Sessions read so far, by page of [_pageSize] rows.
  final Map<int, List<WorkoutSession?>> _pages = {};

  /// Exercise names of the sessions read so far.
  final Map<int, String> _names = {};

  final ScrollController _scroll = ScrollController();

  /// The row a calendar jump landed on, marked for a moment.
  int? _marked;
  Timer? _unmark;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _active = TabVisibilityScope.isActiveOf(context);
    // RepositoryScope is an inherited widget, so read it here (after initState).
    if (!_didLoad) {
      _didLoad = true;
      _repo = RepositoryScope.maybeOf(context);
      _changes = _repo?.sessions.watchChanges().listen(
        (_) => _onSessionsChanged(),
        onError: _onLoadError,
      );
      // Synchronous reads, so the very first frame already shows the list
      // instead of a loading spinner.
      _load(includeGyms: true);
    } else if (_active && (_stale || _error != null)) {
      // Shown again: catch up on saves made meanwhile, or retry a failed
      // read.
      _load();
    }
  }

  @override
  void dispose() {
    _changes?.cancel();
    _unmark?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _onSessionsChanged() {
    // History is built ahead of time while hidden: defer the reload to when
    // the tab is shown instead of rebuilding offstage on every save.
    if (!_active) {
      _stale = true;
      return;
    }
    setState(_load);
  }

  void _onLoadError(Object error, StackTrace stackTrace) {
    AppLog.error('history', error, stackTrace);
    if (mounted) setState(() => _error = error);
  }

  void _load({bool includeGyms = false}) {
    _stale = false;
    final repo = _repo;
    if (repo == null) return;
    try {
      if (includeGyms) {
        _gymNames = {for (final g in repo.gyms.getAllSync()) g.id: g.name};
      }
      final timeline = repo.sessions.getTimelineSync();
      final count = math.min(timeline.ids.length, timeline.starts.length);
      _ids = timeline.ids.sublist(0, count);
      _index = WorkoutDateIndex(timeline.starts.sublist(0, count));
      _pages.clear();
      _names.clear();
      _error = null;
    } on Object catch (error, stackTrace) {
      AppLog.error('history', error, stackTrace);
      _error = error;
    }
  }

  WorkoutSession? _sessionAt(int index) {
    final page = index ~/ _pageSize;
    final sessions = _pages[page] ??= _readPage(page);
    final at = index - page * _pageSize;
    return at < sessions.length ? sessions[at] : null;
  }

  List<WorkoutSession?> _readPage(int page) {
    final repo = _repo;
    if (repo == null) return const [];
    final from = page * _pageSize;
    final ids = _ids.sublist(from, math.min(from + _pageSize, _ids.length));
    try {
      final sessions = repo.sessions.getByIdsSync(ids);
      final missing = <int>{
        for (final session in sessions)
          if (session != null)
            for (final set in session.sets)
              if (!_names.containsKey(set.exerciseId)) set.exerciseId,
      };
      if (missing.isNotEmpty) {
        _names.addAll(repo.exercises.getTitlesSync(missing));
        for (final id in missing) {
          _names[id] ??= 'Exercise $id';
        }
      }
      return sessions;
    } on Object catch (error, stackTrace) {
      AppLog.error('history', error, stackTrace);
      return List.filled(ids.length, null);
    }
  }

  String? _gymNameOf(WorkoutSession session) =>
      session.gymId == null ? null : _gymNames[session.gymId];

  // Layout: rows have known heights, so a calendar jump knows where a day's
  // workout sits without building the rows above it.

  _Metrics _metrics(BuildContext context) => _Metrics.of(context);

  double _extentAt(int index, _Metrics metrics) =>
      metrics.row + (_index.startsMonth(index) ? metrics.heading : 0);

  Future<void> _openCalendar() async {
    final day = await showHistoryCalendar(context, index: _index);
    if (day == null || !mounted) return;
    final target = _index.firstIndexOn(day);
    if (target == null) return;
    final metrics = _metrics(context);
    var offset = 0.0;
    for (var i = 0; i < target; i++) {
      offset += _extentAt(i, metrics);
    }
    // The list scrolls under the pinned app bar, right after the restore
    // strip: only the strip scrolls away before it.
    final before = _restoreKey.currentContext?.size?.height ?? 0;
    _unmark?.cancel();
    setState(() => _marked = target);
    _unmark = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _marked = null);
    });
    // A jump, not an animation: the list only estimates its length until
    // its end is built, and an animation would stop at that estimate.
    _scroll.jumpTo(math.max(0, before + offset));
  }

  final _restoreKey = GlobalKey(debugLabel: 'history restore strip');

  @override
  Widget build(BuildContext context) {
    final metrics = _metrics(context);
    final hasWorkouts = _error == null && !_index.isEmpty;
    return CustomScrollView(
      controller: _scroll,
      slivers: <Widget>[
        CustomAppBar(
          context,
          title: 'History',
          trailing: hasWorkouts
              ? AppIconButton(
                  icon: FLucideIcons.calendarDays,
                  tooltip: 'Calendar',
                  onPress: _openCalendar,
                )
              : null,
        ),
        SliverToBoxAdapter(
          child: MaxWidth(key: _restoreKey, child: const _RestoreSlot()),
        ),
        if (_error != null)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _HistoryMessage(
              icon: FLucideIcons.circleAlert,
              title: 'History could not be loaded',
              message:
                  'Your workouts are still saved. Leave this tab and come '
                  'back to try again.',
            ),
          )
        else if (_index.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _HistoryMessage(
              icon: FLucideIcons.history,
              title: 'No workouts logged yet',
              message:
                  'Finish a workout in the Workout tab and it shows up '
                  'here, with every set you logged.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 32),
            sliver: SliverVariedExtentList.builder(
              itemCount: _ids.length,
              itemExtentBuilder: (index, _) =>
                  index < _ids.length ? _extentAt(index, metrics) : null,
              itemBuilder: (context, index) => _row(context, index, metrics),
            ),
          ),
      ],
    );
  }

  Widget _row(BuildContext context, int index, _Metrics metrics) {
    final session = _sessionAt(index);
    final start = _index.startAt(index);
    final heading = _index.startsMonth(index)
        ? _MonthHeading(
            label: monthLabel(start.year, start.month),
            count: _index.countInMonth(start.year, start.month),
            height: metrics.heading,
          )
        : null;
    final Widget row = session == null
        ? SizedBox(height: metrics.row)
        : _SessionRow(
            session: session,
            names: _names,
            height: metrics.row,
            marked: _marked == index,
            onOpen: () => pushTo(
              context,
              SessionDetailPage(session: session, gymName: _gymNameOf(session)),
            ),
          );
    return MaxWidth(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[?heading, row],
        ),
      ),
    );
  }
}

/// Row and heading heights, from the text they hold at the current text
/// size, so every row of the list has a height known before it is built.
class _Metrics {
  const _Metrics({required this.row, required this.heading});

  factory _Metrics.of(BuildContext context) {
    final type = context.theme.typography.body;
    final scaler = MediaQuery.textScalerOf(context);
    double line(TextStyle style, double height) =>
        scaler.scale(style.fontSize ?? 14) * height;
    final middle = line(type.sm, _rowLine) + 2 + line(type.xs, _rowLine);
    final gutter = line(type.xs2, _rowLine) + line(type.md, _dayLine);
    return _Metrics(
      row: (math.max(math.max(middle, gutter), 40) + 2 * _rowPadding + 1)
          .ceilToDouble(),
      heading: (line(type.xs, _rowLine) + 26).ceilToDouble(),
    );
  }

  final double row;
  final double heading;
}

const double _rowPadding = 10;
const double _rowLine = 1.3;
const double _dayLine = 1.15;

class _MonthHeading extends StatelessWidget {
  const _MonthHeading({
    required this.label,
    required this.count,
    required this.height,
  });

  final String label;
  final int count;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.body.xs.copyWith(
                  fontWeight: FontWeight.w600,
                  height: _rowLine,
                ),
              ),
            ),
            Text(
              plural('workout', count),
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.mutedForeground,
                height: _rowLine,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One finished workout: the day on the left, what was done in the middle,
/// how long it took and its working sets on the right.
class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.session,
    required this.names,
    required this.height,
    required this.marked,
    required this.onOpen,
  });

  final WorkoutSession session;
  final Map<int, String> names;
  final double height;

  /// Just jumped to from the calendar.
  final bool marked;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final type = theme.typography.body;
    final muted = theme.colors.mutedForeground;
    final start = session.startTime;
    final end = session.endTime;
    final exercises = [
      for (final group in groupByExercise(session.sets))
        names[group.exerciseId] ?? 'Exercise ${group.exerciseId}',
    ];
    const tabular = [FontFeature.tabularFigures()];
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          height: height,
          padding: const EdgeInsets.symmetric(
            horizontal: 2,
            vertical: _rowPadding,
          ),
          decoration: BoxDecoration(
            color: marked ? theme.colors.muted : theme.colors.background,
            border: Border(bottom: BorderSide(color: theme.colors.border)),
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 36,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      weekdayLabel(start),
                      maxLines: 1,
                      style: type.xs2.copyWith(color: muted, height: _rowLine),
                    ),
                    Text(
                      '${start.day}',
                      maxLines: 1,
                      style: type.md.copyWith(
                        fontWeight: FontWeight.w700,
                        height: _dayLine,
                        fontFeatures: tabular,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      session.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.sm.copyWith(
                        fontWeight: FontWeight.w600,
                        height: _rowLine,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      exercisePreview(exercises),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.xs.copyWith(color: muted, height: _rowLine),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  if (end != null)
                    Text(
                      lengthLabel(end.difference(start)),
                      maxLines: 1,
                      style: type.xs.copyWith(
                        fontWeight: FontWeight.w600,
                        height: _rowLine,
                        fontFeatures: tabular,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    plural('set', workingSetCount(session.sets)),
                    maxLines: 1,
                    style: type.xs.copyWith(
                      color: muted,
                      height: _rowLine,
                      fontFeatures: tabular,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The last discarded workout, while it can still be brought back and no
/// other workout is running.
class _RestoreSlot extends StatefulWidget {
  const _RestoreSlot();

  @override
  State<_RestoreSlot> createState() => _RestoreSlotState();
}

class _RestoreSlotState extends State<_RestoreSlot> {
  /// Rebuilds when the restore window closes: no state change marks it.
  Timer? _expiry;

  @override
  void dispose() {
    _expiry?.cancel();
    super.dispose();
  }

  void _scheduleExpiry(WorkoutState state) {
    _expiry?.cancel();
    final at = state.discardedAt;
    if (at == null) return;
    final left = at
        .add(WorkoutState.discardRestoreWindow)
        .difference(DateTime.now());
    if (left.isNegative) return;
    _expiry = Timer(left + const Duration(seconds: 1), () {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final WorkoutCubit cubit;
    try {
      cubit = context.read<WorkoutCubit>();
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }
    return BlocBuilder<WorkoutCubit, WorkoutState>(
      bloc: cubit,
      buildWhen: (a, b) =>
          a.isInProgress != b.isInProgress ||
          a.discardedSnapshot != b.discardedSnapshot ||
          a.discardedAt != b.discardedAt,
      builder: (context, state) {
        final restorable = state.canRestoreDiscarded();
        if (restorable) {
          _scheduleExpiry(state);
        } else {
          _expiry?.cancel();
        }
        final snapshot = state.discardedSnapshot;
        return AnimatedReveal(
          child: restorable && snapshot != null
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
                  child: RestoreStrip(
                    title: snapshot.planTitle ?? 'Free workout',
                    discardedAt: state.discardedAt!,
                    sets: snapshot.sets.length,
                    onRestore: () {
                      cubit.restoreDiscardedWorkout();
                      HomePageSingleton().changeTab(TabName.currentWorkout);
                    },
                  ),
                )
              : null,
        );
      },
    );
  }
}

/// Where the page says what is (not) there and what to do about it.
class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 36, color: theme.colors.mutedForeground),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.typography.body.sm.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.mutedForeground,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
