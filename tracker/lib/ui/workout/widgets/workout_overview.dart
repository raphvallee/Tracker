import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/split_draft.dart';
import 'package:tracker/domain/services/set_prefill.dart';
import 'package:tracker/ui/core/themes/accents.dart';
import 'package:tracker/ui/core/ui/accent_button.dart';
import 'package:tracker/ui/core/ui/app_dialog.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/core/ui/icon_button.dart';
import 'package:tracker/ui/core/ui/max_width.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

import 'elapsed_clock.dart';
import 'exercise_page.dart';
import 'exercise_picker_page.dart';
import 'finish_workout.dart';
import 'gym_picker.dart';
import 'plan_bar.dart';
import 'workout_dock.dart';
import 'workout_entries.dart';

export 'workout_entries.dart';

class _Overview {
  _Overview(WorkoutState state)
    : title = state.planTitle ?? 'Free workout',
      gymId = state.gymId,
      gymName = state.gymName,
      startTime = state.startTime ?? DateTime.now(),
      isPlan = state.planTitle != null,
      entries = workoutEntries(state),
      setCount = state.sets.length;

  final String title;
  final int? gymId;
  final String? gymName;
  final DateTime startTime;
  final bool isPlan;
  final List<WorkoutEntry> entries;
  final int setCount;

  ({int done, int total}) get progress => plannedProgress(entries);

  /// The plan exercise to do next: the first one with planned sets left.
  int? get current {
    if (!isPlan) return null;
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].planned > 0 && !entries[i].isDone) return i;
    }
    return null;
  }

  /// The exercise the dock's Continue opens: the plan's current one; in a
  /// free workout the exercise just added, until its first set is logged.
  WorkoutEntry? get upNext {
    final at = current;
    if (at != null) return entries[at];
    if (isPlan || entries.isEmpty) return null;
    return entries.last.sets.isEmpty ? entries.last : null;
  }
}

/// The running workout: its exercises in order, each opening its own page,
/// and the next step docked at the bottom.
class WorkoutOverview extends StatelessWidget {
  const WorkoutOverview({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<WorkoutCubit, WorkoutState, _Overview>(
      selector: _Overview.new,
      builder: (context, overview) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Header(overview: overview),
          Expanded(
            child: MaxWidth(
              child: overview.entries.isEmpty
                  ? const _NoExercises()
                  : _ExerciseList(
                      overview: overview,
                      onAdd: () => _addExercise(context),
                    ),
            ),
          ),
          WorkoutDock(child: _nextStep(context, overview)),
        ],
      ),
    );
  }

  /// The one next step: the exercise to carry on with, Finish once the plan
  /// is done, and in a free workout the next exercise to add.
  Widget _nextStep(BuildContext context, _Overview overview) {
    final upNext = overview.upNext;
    if (upNext != null) {
      final prefill = SettingsCubit.maybeOf(context)?.state.prefillSets ?? true;
      // The set the page opens on rides on the side: "Set 3".
      return _WithPrevious(
        exerciseId: upNext.exercise.exerciseId,
        builder: (context, previous) => AccentButton(
          large: true,
          label: 'Continue ${upNext.exercise.name}',
          trailing: _nextSetName(upNext, prefill ? previous : null),
          onPress: () => pushTo<void>(
            context,
            ExercisePage(exerciseId: upNext.exercise.exerciseId),
          ),
        ),
      );
    }
    if (overview.isPlan && overview.entries.isNotEmpty) {
      return AccentButton(
        large: true,
        label: 'Finish workout',
        onPress: () => finishWorkout(context),
      );
    }
    return AccentButton(
      large: true,
      prefix: FLucideIcons.plus,
      label: 'Add exercise',
      onPress: () => _addExercise(context),
    );
  }

  static Future<void> _addExercise(BuildContext context) async {
    final cubit = context.read<WorkoutCubit>();
    final exercise = await pushTo<Exercise>(
      context,
      const ExercisePickerPage(),
    );
    if (exercise == null || !context.mounted) return;
    final added = cubit.addExercise(
      exerciseId: exercise.id,
      name: exercise.title,
    );
    if (!added) {
      showFToast(
        context: context,
        title: Text('${exercise.title} is already in this workout'),
        duration: const Duration(seconds: 3),
      );
      return;
    }
    // A new exercise is about to be logged: open it straight away.
    pushTo<void>(context, ExercisePage(exerciseId: exercise.id));
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.overview});

  final _Overview overview;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final accents = TrackerAccents.of(context);
    final muted = theme.typography.body.xs.copyWith(
      color: theme.colors.mutedForeground,
    );
    final progress = overview.progress;
    final gymName = overview.gymName;
    return ColoredBox(
      color: theme.colors.background,
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        child: MaxWidth(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        overview.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.body.xl.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Used once per workout: quiet here, and the dock turns
                    // into Finish when the plan is done.
                    FButton(
                      variant: .outline,
                      size: .sm,
                      mainAxisSize: .min,
                      onPress: () => finishWorkout(context),
                      child: const Text('Finish'),
                    ),
                    _menu(context),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    children: <Widget>[
                      ElapsedClock(
                        start: overview.startTime,
                        style: theme.typography.body.sm.copyWith(
                          color: accents.live,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (progress.total == 0) ...[
                        const SizedBox(width: 12),
                        Text(plural('set', overview.setCount), style: muted),
                      ],
                      if (gymName != null) ...[
                        const SizedBox(width: 12),
                        Flexible(
                          child: _GymChip(
                            name: gymName,
                            onPress: () => _changeGym(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (progress.total > 0) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: PlanBar(
                            segments: planSegments(
                              overview.entries,
                              current: overview.current,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${progress.done} of '
                          '${plural('set', progress.total)}',
                          style: muted,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _menu(BuildContext context) {
    final destructive = context.theme.colors.destructive;
    return FPopoverMenu.tiles(
      menuAnchor: .topRight,
      childAnchor: .bottomRight,
      menuBuilder: (menuContext, controller, _) => [
        .group(
          children: [
            .tile(
              prefix: const Icon(FLucideIcons.mapPin),
              title: const Text('Change gym'),
              onPress: () {
                controller.hide();
                _changeGym(context);
              },
            ),
            .tile(
              prefix: Icon(FLucideIcons.trash2, color: destructive),
              title: Text(
                'Discard workout',
                style: TextStyle(color: destructive),
              ),
              onPress: () {
                controller.hide();
                _discard(context);
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
  }

  Future<void> _changeGym(BuildContext context) async {
    final cubit = context.read<WorkoutCubit>();
    final gyms =
        await RepositoryScope.maybeOf(context)?.gyms.getAll() ?? <Gym>[];
    if (!context.mounted) return;
    final picked = await showGymPicker(
      context,
      gyms,
      currentId: cubit.state.gymId,
      oneWorkoutOnly: true,
    );
    if (picked is Gym) cubit.setGym(picked);
  }

  Future<void> _discard(BuildContext context) async {
    final cubit = context.read<WorkoutCubit>();
    if (await confirmDiscardWorkout(context) && context.mounted) {
      await cubit.discardWorkout();
    }
  }
}

/// The gym the workout is at, in the header: a tap changes it.
class _GymChip extends StatelessWidget {
  const _GymChip({required this.name, required this.onPress});

  final String name;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return FTappable(
      semanticsLabel: 'Gym: $name. Change gym',
      onPress: onPress,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: theme.colors.muted,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(FLucideIcons.mapPin, size: 14),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.body.xs.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              FLucideIcons.chevronDown,
              size: 14,
              color: theme.colors.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseList extends StatelessWidget {
  const _ExerciseList({required this.overview, required this.onAdd});

  final _Overview overview;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WorkoutCubit>();
    final current = overview.current;
    final entries = overview.entries;
    final reorderable = entries.where((entry) => entry.listed).length;
    return ReorderableListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      buildDefaultDragHandles: false,
      onReorderItem: (oldIndex, newIndex) {
        if (oldIndex >= reorderable) return;
        cubit.reorderExercise(oldIndex, newIndex.clamp(0, reorderable - 1));
      },
      // Once a free workout has nothing waiting, the dock adds the next
      // exercise; the row would repeat it.
      footer: overview.isPlan || overview.upNext != null
          ? _AddExerciseRow(onPress: onAdd)
          : null,
      children: <Widget>[
        for (final (index, entry) in entries.indexed)
          Dismissible(
            key: ValueKey('overview-${entry.exercise.exerciseId}'),
            direction: DismissDirection.endToStart,
            background: const _RemoveBackground(),
            confirmDismiss: (_) => _confirmRemove(context, entry),
            onDismissed: (_) => cubit.removeExercise(entry.exercise.exerciseId),
            child: ReorderableDelayedDragStartListener(
              index: index,
              enabled: entry.listed,
              child: _EntryTile(
                index: index,
                entry: entry,
                isCurrent: index == current,
                onOpen: () => pushTo<void>(
                  context,
                  ExercisePage(exerciseId: entry.exercise.exerciseId),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<bool> _confirmRemove(BuildContext context, WorkoutEntry entry) async {
    if (entry.sets.isEmpty) return true;
    return showConfirmDialog(
      context,
      title: 'Remove ${entry.exercise.name}?',
      message:
          'This will delete its ${plural('set', entry.sets.length)} from '
          'this workout.',
      confirmLabel: 'Remove',
      destructive: true,
    );
  }
}

class _RemoveBackground extends StatelessWidget {
  const _RemoveBackground();

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return Container(
      alignment: AlignmentDirectional.centerEnd,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: colors.destructive,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(FLucideIcons.trash2, color: colors.destructiveForeground),
    );
  }
}

/// One exercise row: where it stands on the left, its sets count anchored
/// on the right ("2 of 4"). The current one is outlined in the live accent.
class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.index,
    required this.entry,
    required this.isCurrent,
    required this.onOpen,
  });

  final int index;
  final WorkoutEntry entry;
  final bool isCurrent;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final accents = TrackerAccents.of(context);
    final muted = theme.typography.body.xs.copyWith(
      color: theme.colors.mutedForeground,
    );
    final Widget subtitle;
    if (entry.isDone) {
      final best = _bestSet(entry.sets);
      subtitle = Text(
        best == null
            ? 'Done'
            : 'Best set ${formatWeight(context, best.weight)} × '
                  '${formatReps(best.reps)}',
        style: muted,
      );
    } else if (isCurrent) {
      subtitle = _NextSet(entry: entry);
    } else {
      // What it asks for, and what it did last time: enough to go and load
      // the bar before its turn.
      subtitle = _WithPrevious(
        exerciseId: entry.exercise.exerciseId,
        builder: (context, previous) {
          final top = entry.sets.isEmpty ? previous?.topSet : null;
          final detail = _upcomingDetail(entry);
          return Text(
            top == null
                ? detail
                : '$detail, last ${formatWeight(context, top.weight)} × '
                      '${formatReps(top.reps)}',
            style: muted,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        },
      );
    }
    final Widget trailing = entry.planned > 0
        ? Text(
            '${entry.workingLogged} of ${entry.planned}',
            style: isCurrent
                ? theme.typography.body.xs.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )
                : muted.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
          )
        : Icon(
            FLucideIcons.chevronRight,
            size: 18,
            color: theme.colors.mutedForeground,
          );
    final row = Row(
      children: <Widget>[
        if (entry.isDone)
          const _DoneMark()
        else
          SizedBox(
            width: 24,
            child: Text(
              '${index + 1}',
              textAlign: TextAlign.center,
              style: muted,
            ),
          ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                entry.exercise.name,
                style:
                    (isCurrent
                            ? theme.typography.body.md
                            : theme.typography.body.sm)
                        .copyWith(
                          fontWeight: isCurrent
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
              ),
              const SizedBox(height: 3),
              subtitle,
            ],
          ),
        ),
        const SizedBox(width: 8),
        trailing,
      ],
    );
    // Both shapes inset their content by 14, so the counts line up.
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isCurrent ? 8 : 0),
      child: FTappable(
        onPress: onOpen,
        child: Container(
          constraints: BoxConstraints(minHeight: isCurrent ? 68 : 60),
          padding: EdgeInsets.symmetric(
            horizontal: isCurrent ? 12 : 14,
            vertical: 10,
          ),
          decoration: isCurrent
              ? BoxDecoration(
                  color: theme.colors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accents.live, width: 2),
                )
              : BoxDecoration(
                  color: theme.colors.background,
                  border: Border(
                    bottom: BorderSide(color: theme.colors.border),
                  ),
                ),
          child: row,
        ),
      ),
    );
  }

  /// What a waiting exercise asks for: its rep target ("8-12 reps"), the
  /// count being on the right; without a plan, what is logged so far.
  static String _upcomingDetail(WorkoutEntry entry) {
    if (entry.planned == 0) {
      return entry.sets.isEmpty
          ? 'No sets yet'
          : '${plural('set', entry.sets.length)} logged';
    }
    final targets = [
      for (final set in entry.exercise.sets) SetTarget.fromPlanned(set),
    ];
    final working = [
      for (final target in targets)
        if (!target.warmup) target,
    ];
    final warmups = targets.length - working.length;
    final reps = working.every((target) => target == working.first)
        ? '${working.first.label} ${working.first.unit}'
        : '${working.map((target) => target.label).join(', ')} reps';
    return warmups == 0 ? reps : '${plural('warm-up', warmups)}, then $reps';
  }
}

ActiveSet? _bestSet(List<ActiveSet> sets) {
  ActiveSet? best;
  for (final set in sets) {
    if (set.isWarmup) continue;
    if (best == null ||
        set.weight > best.weight ||
        (set.weight == best.weight && set.reps > best.reps)) {
      best = set;
    }
  }
  return best;
}

class _DoneMark extends StatelessWidget {
  const _DoneMark();

  @override
  Widget build(BuildContext context) {
    final accents = TrackerAccents.of(context);
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(shape: BoxShape.circle, color: accents.live),
      child: Icon(FLucideIcons.check, size: 14, color: accents.liveForeground),
    );
  }
}

/// The row the exercise page opens [entry] on, named as its badge names it:
/// "Set 3", or "Warm-up". Null without a plan to count against.
String? _nextSetName(WorkoutEntry entry, PreviousPerformance? previous) {
  if (entry.planned == 0) return null;
  final index = entry.sets.length;
  final lead = leadingWarmupRows(entry.exercise.sets, previous);
  final planned = plannedForRow(index, entry.exercise.sets, lead: lead);
  if (index < lead || (planned?.isWarmup ?? false)) return 'Warm-up';
  return 'Set ${entry.workingLogged + 1}';
}

/// Builds with the sets [exerciseId] got in the last session that logged
/// it: null until they load, and when no session did.
class _WithPrevious extends StatefulWidget {
  const _WithPrevious({required this.exerciseId, required this.builder});

  final int exerciseId;
  final Widget Function(BuildContext context, PreviousPerformance? previous)
  builder;

  @override
  State<_WithPrevious> createState() => _WithPreviousState();
}

class _WithPreviousState extends State<_WithPrevious> {
  Future<PreviousPerformance?>? _previous;
  int? _loadedFor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(covariant _WithPrevious oldWidget) {
    super.didUpdateWidget(oldWidget);
    _load();
  }

  void _load() {
    if (_loadedFor == widget.exerciseId) return;
    _loadedFor = widget.exerciseId;
    _previous = RepositoryScope.maybeOf(context)?.sessions
        .getPreviousPerformance(widget.exerciseId);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<PreviousPerformance?>(
    future: _previous,
    builder: (context, snapshot) => widget.builder(context, snapshot.data),
  );
}

/// "Next set 30 kg × 10" from the prefill, else the next planned target.
class _NextSet extends StatelessWidget {
  const _NextSet({required this.entry});

  final WorkoutEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final style = theme.typography.body.xs;
    final prefill = SettingsCubit.maybeOf(context)?.state.prefillSets ?? true;
    return _WithPrevious(
      exerciseId: entry.exercise.exerciseId,
      builder: (context, loaded) {
        final index = entry.sets.length;
        final last = entry.sets.isEmpty ? null : entry.sets.last;
        final previous = prefill ? loaded : null;
        final lead = leadingWarmupRows(entry.exercise.sets, previous);
        final ghost = ghostForRow(
          index: index,
          previous: previous,
          planned: entry.exercise.sets,
          lead: lead,
          previousWeight: last?.weight,
          previousReps: last?.reps,
        );
        final weight = ghost.weight;
        final reps = ghost.reps;
        if (prefill && weight != null && reps != null) {
          return Text(
            'Next set ${formatWeight(context, weight)} × ${formatReps(reps)}',
            style: style,
          );
        }
        final planned = plannedForRow(index, entry.exercise.sets, lead: lead);
        final target = planned == null
            ? null
            : SetTarget.fromPlanned(planned).description;
        return Text(
          target == null ? 'Next: set ${index + 1}' : 'Next set: $target',
          style: style,
        );
      },
    );
  }
}

class _AddExerciseRow extends StatelessWidget {
  const _AddExerciseRow({required this.onPress});

  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FButton(
          variant: .ghost,
          mainAxisSize: .min,
          onPress: onPress,
          prefix: const Icon(FLucideIcons.plus),
          child: const Text('Add exercise'),
        ),
      ),
    );
  }
}

class _NoExercises extends StatelessWidget {
  const _NoExercises();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: <Widget>[
        Text(
          'Add an exercise to start logging sets.',
          textAlign: TextAlign.center,
          style: theme.typography.body.sm.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
      ],
    );
  }
}
