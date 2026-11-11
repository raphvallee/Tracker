import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/services/session_summary.dart';
import 'package:tracker/routing/tab_navigation.dart';
import 'package:tracker/ui/core/themes/accents.dart';
import 'package:tracker/ui/core/ui/animated_reveal.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/core/ui/effort_format.dart';
import 'package:tracker/ui/core/ui/icon_button.dart';
import 'package:tracker/ui/core/ui/max_width.dart';
import 'package:tracker/ui/core/ui/plan_bar.dart';
import 'package:tracker/ui/core/ui/relative_dates.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/core/ui/set_badge.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

import 'session_edit_page.dart';

/// A past workout, as it was logged: when and where, how much, and every set
/// under its exercise. Each exercise folds to its best set. Edit opens the
/// workout as a draft; Restore (when the cubit can) makes it live again.
class SessionDetailPage extends StatefulWidget {
  const SessionDetailPage({super.key, required this.session, this.gymName});

  final WorkoutSession session;

  final String? gymName;

  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  late WorkoutSession _session;
  String? _gymName;
  Map<int, String> _names = const {};
  bool _didLoad = false;

  /// Exercises folded to one line, while the page is open.
  final Set<int> _folded = {};

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _gymName = widget.gymName;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    _readNames();
    if (_gymName == null) _resolveGymName();
  }

  /// A handful of names, read at once: the first frame shows them.
  void _readNames() {
    final repo = RepositoryScope.maybeOf(context);
    if (repo == null) return;
    _names = repo.exercises.getTitlesSync(
      _session.sets.map((set) => set.exerciseId),
    );
  }

  Future<void> _resolveGymName() async {
    final gymId = _session.gymId;
    if (gymId == null) {
      setState(() => _gymName = null);
      return;
    }
    final gym = await RepositoryScope.maybeOf(context)?.gyms.getById(gymId);
    if (!mounted) return;
    setState(() => _gymName = gym?.name);
  }

  String _nameOf(int exerciseId) =>
      _names[exerciseId] ?? 'Exercise $exerciseId';

  Future<void> _edit() async {
    final result = await pushTo<SessionEditResult>(
      context,
      SessionEditPage(session: _session),
    );
    if (!mounted || result == null) return;
    switch (result) {
      case SessionDeleted():
        // The workout is gone: back to where it was listed.
        Navigator.of(context).pop();
      case SessionSaved(:final session):
        setState(() {
          _session = session;
          _readNames();
        });
        await _resolveGymName();
    }
  }

  bool _canRestore(WorkoutState state) =>
      !state.isInProgress && state.savedSessionId == _session.id;

  Future<void> _restore() async {
    final cubit = context.read<WorkoutCubit>();
    final navigator = Navigator.of(context);
    await cubit.restoreSavedWorkout();
    if (!mounted) return;
    if (!cubit.state.isInProgress) {
      showFToast(
        context: context,
        title: const Text('Could not restore the workout.'),
        duration: const Duration(seconds: 4),
      );
      return;
    }
    // It left History and is running again: go and see it.
    navigator.pop();
    HomePageSingleton().changeTab(TabName.currentWorkout);
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final groups = groupByExercise(session.sets);
    return CustomScrollView(
      slivers: <Widget>[
        CustomAppBar(
          context,
          title: session.title,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              FButton(
                variant: .outline,
                size: .sm,
                mainAxisSize: .min,
                onPress: _edit,
                child: const Text('Edit'),
              ),
              _menu(context),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: MaxWidth(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _Facts(session: session, gymName: _gymName),
                  const SizedBox(height: 12),
                  _Bar(groups: groups, sets: session.sets),
                  const SizedBox(height: 4),
                  if (groups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No sets were logged in this workout.',
                        style: context.theme.typography.body.xs.copyWith(
                          color: context.theme.colors.mutedForeground,
                        ),
                      ),
                    ),
                  for (final (i, group) in groups.indexed)
                    _ExerciseBlock(
                      name: _nameOf(group.exerciseId),
                      group: group,
                      first: i == 0,
                      folded: _folded.contains(group.exerciseId),
                      onToggle: () => setState(() {
                        if (!_folded.remove(group.exerciseId)) {
                          _folded.add(group.exerciseId);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Restore, only while the cubit can bring this workout back.
  Widget _menu(BuildContext context) {
    WorkoutCubit? cubit;
    try {
      cubit = context.read<WorkoutCubit>();
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }
    return BlocBuilder<WorkoutCubit, WorkoutState>(
      bloc: cubit,
      buildWhen: (a, b) =>
          a.isInProgress != b.isInProgress ||
          a.savedSessionId != b.savedSessionId,
      builder: (context, state) {
        if (!_canRestore(state)) return const SizedBox.shrink();
        final live = TrackerAccents.of(context).live;
        return FPopoverMenu.tiles(
          menuAnchor: .topRight,
          childAnchor: .bottomRight,
          menuBuilder: (menuContext, controller, _) => [
            .group(
              children: [
                .tile(
                  prefix: Icon(FLucideIcons.rotateCcw, color: live),
                  title: const Text('Restore workout'),
                  onPress: () {
                    controller.hide();
                    _restore();
                  },
                ),
              ],
            ),
          ],
          builder: (_, controller, _) => AppIconButton(
            icon: FLucideIcons.ellipsis,
            tooltip: 'Workout options',
            onPress: controller.toggle,
          ),
        );
      },
    );
  }
}

/// When it ran, then how long, where and how much was lifted.
class _Facts extends StatelessWidget {
  const _Facts({required this.session, required this.gymName});

  final WorkoutSession session;
  final String? gymName;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final start = session.startTime;
    final end = session.endTime;
    final where = [
      if (end != null) lengthLabel(end.difference(start)),
      if (gymName != null) 'at $gymName',
    ].join(' ');
    final details = [
      if (where.isNotEmpty) '${where[0].toUpperCase()}${where.substring(1)}',
      '${formatVolume(context, workingVolumeOf(session.sets))} lifted',
    ].join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          timeRangeLabel(start, end),
          style: theme.typography.body.sm.copyWith(
            fontWeight: FontWeight.w500,
            height: 1.3,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          details,
          style: theme.typography.body.xs.copyWith(
            color: theme.colors.mutedForeground,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

/// The workout's shape, finished: a segment per exercise as wide as its
/// working sets, all in ink, with their count beside it.
class _Bar extends StatelessWidget {
  const _Bar({required this.groups, required this.sets});

  final List<ExerciseSets> groups;
  final List<WorkoutSet> sets;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Row(
      children: <Widget>[
        Expanded(
          child: PlanBar(
            ink: true,
            segments: [
              for (final group in groups)
                PlanSegment(sets: group.workingCount, progress: 1),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          plural('set', workingSetCount(sets)),
          style: theme.typography.body.xs.copyWith(
            color: theme.colors.mutedForeground,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// An exercise and its sets; a tap on its name folds it to its best set.
class _ExerciseBlock extends StatelessWidget {
  const _ExerciseBlock({
    required this.name,
    required this.group,
    required this.first,
    required this.folded,
    required this.onToggle,
  });

  final String name;
  final ExerciseSets group;
  final bool first;
  final bool folded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final muted = theme.colors.mutedForeground;
    final best = group.topSet;
    var working = 0;
    final rows = <Widget>[
      for (final set in group.sets)
        _SetLine(set: set, label: set.isWarmup ? 'W' : '${++working}'),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        border: first
            ? null
            : Border(top: BorderSide(color: theme.colors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              button: true,
              expanded: !folded,
              hint: folded ? 'Shows every set' : 'Folds to the best set',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.body.sm.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        setCountsLabel(group.workingCount, group.warmupCount),
                        style: theme.typography.body.xs.copyWith(color: muted),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        folded
                            ? FLucideIcons.chevronDown
                            : FLucideIcons.chevronUp,
                        size: 15,
                        color: muted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedReveal(
              child: folded
                  ? null
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: rows,
                    ),
            ),
            AnimatedReveal(
              child: folded && best != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Best set ${formatWeight(context, best.weight)} × '
                        '${formatReps(best.reps)}',
                        style: theme.typography.body.xs.copyWith(color: muted),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// One set in shared columns: badge, weight, unit, times sign, reps, and
/// its rating at the end when it has one.
class _SetLine extends StatelessWidget {
  const _SetLine({required this.set, required this.label});

  final WorkoutSet set;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final muted = theme.colors.mutedForeground;
    const tabular = [FontFeature.tabularFigures()];
    final number = theme.typography.body.xs.copyWith(
      fontWeight: FontWeight.w600,
      fontFeatures: tabular,
    );
    final quiet = theme.typography.body.xs.copyWith(
      color: muted,
      fontFeatures: tabular,
    );
    final rpe = set.rpe;
    return SizedBox(
      height: 30,
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 30,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: SetBadge(label: label, warmup: set.isWarmup, size: 20),
            ),
          ),
          SizedBox(
            width: 56,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                formatDecimal(displayWeightOf(context, set.weight)),
                style: number,
              ),
            ),
          ),
          SizedBox(
            width: 28,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 4),
              child: Text(weightUnitOf(context).symbol, style: quiet),
            ),
          ),
          SizedBox(
            width: 16,
            child: Text('×', textAlign: TextAlign.center, style: quiet),
          ),
          SizedBox(
            width: 48,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(formatReps(set.reps), style: number),
            ),
          ),
          Expanded(
            child: Text(
              rpe == null ? '' : effortLabel(effortScaleOf(context), rpe),
              textAlign: TextAlign.end,
              maxLines: 1,
              style: quiet,
            ),
          ),
        ],
      ),
    );
  }
}
