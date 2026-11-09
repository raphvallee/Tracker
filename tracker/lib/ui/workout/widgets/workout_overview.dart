import 'dart:math' as math;

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
import 'gym_picker.dart';

/// One exercise of the running workout, as the overview lists it.
class WorkoutEntry {
  const WorkoutEntry({
    required this.exercise,
    required this.sets,
    this.listed = true,
  });

  final PlanExercise exercise;
  final List<ActiveSet> sets;

  /// False for sets logged without a card of their own (sessions saved
  /// before free workouts kept their exercises): they cannot be reordered.
  final bool listed;

  int get planned => exercise.sets.length;

  int get workingLogged => sets.where((set) => !set.isWarmup).length;

  bool get isDone => planned > 0 && workingLogged >= planned;
}

/// The running workout's exercises in card order.
List<WorkoutEntry> workoutEntries(WorkoutState state) {
  final grouped = state.setsByExercise;
  final listed = {for (final exercise in state.plan) exercise.exerciseId};
  return [
    for (final exercise in state.plan)
      WorkoutEntry(
        exercise: exercise,
        sets: grouped[exercise.exerciseId] ?? const [],
      ),
    for (final MapEntry(key: id, value: sets) in grouped.entries)
      if (!listed.contains(id))
        WorkoutEntry(
          exercise: PlanExercise(
            exerciseId: id,
            name: sets.first.exerciseName,
            order: state.plan.length,
          ),
          sets: sets,
          listed: false,
        ),
  ];
}

class _Overview {
  _Overview(WorkoutState state)
    : title = state.planTitle ?? 'Free workout',
      gymName = state.gymName,
      startTime = state.startTime ?? DateTime.now(),
      isPlan = state.planTitle != null,
      entries = workoutEntries(state),
      setCount = state.sets.length;

  final String title;
  final String? gymName;
  final DateTime startTime;
  final bool isPlan;
  final List<WorkoutEntry> entries;
  final int setCount;

  /// Working sets logged toward the plan, out of the plan's sets. Warm-ups
  /// and sets beyond the plan do not move it.
  ({int done, int total}) get progress {
    var done = 0;
    var total = 0;
    for (final entry in entries) {
      if (entry.planned == 0) continue;
      total += entry.planned;
      done += math.min(entry.workingLogged, entry.planned);
    }
    return (done: done, total: total);
  }

  /// The plan exercise to do next: the first one with planned sets left.
  int? get current {
    if (!isPlan) return null;
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].planned > 0 && !entries[i].isDone) return i;
    }
    return null;
  }
}

/// The running workout: its exercises in order, each opening its own page.
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
                  ? _NoExercises(onAdd: () => _addExercise(context))
                  : _ExerciseList(
                      overview: overview,
                      onAdd: () => _addExercise(context),
                    ),
            ),
          ),
        ],
      ),
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

enum _MenuAction { changeGym, cancel }

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
    return ColoredBox(
      color: theme.colors.background,
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        child: MaxWidth(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 12, 10),
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
                    _menu(context),
                    const SizedBox(width: 4),
                    FButton(
                      size: .sm,
                      mainAxisSize: .min,
                      onPress: () => _finish(context, overview.setCount),
                      child: const Text('Finish'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    ElapsedClock(
                      start: overview.startTime,
                      style: theme.typography.body.sm.copyWith(
                        color: accents.live,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      progress.total > 0
                          ? '${progress.done} of ${plural('set', progress.total)}'
                          : plural('set', overview.setCount),
                      style: muted,
                    ),
                    if (overview.gymName != null) ...[
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          overview.gymName!,
                          style: muted,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                if (progress.total > 0) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      value: progress.done / progress.total,
                      color: accents.live,
                      backgroundColor: theme.colors.muted,
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
                _onMenu(context, _MenuAction.changeGym);
              },
            ),
            .tile(
              prefix: Icon(FLucideIcons.trash2, color: destructive),
              title: Text(
                'Cancel workout',
                style: TextStyle(color: destructive),
              ),
              onPress: () {
                controller.hide();
                _onMenu(context, _MenuAction.cancel);
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

  Future<void> _onMenu(BuildContext context, _MenuAction action) async {
    final cubit = context.read<WorkoutCubit>();
    switch (action) {
      case _MenuAction.changeGym:
        final gyms =
            await RepositoryScope.maybeOf(context)?.gyms.getAll() ?? <Gym>[];
        if (!context.mounted) return;
        final picked = await showGymPicker(context, gyms);
        if (picked is Gym) cubit.setGym(picked);
      case _MenuAction.cancel:
        final confirmed = await showConfirmDialog(
          context,
          title: 'Cancel workout?',
          message: cubit.state.sets.isEmpty
              ? 'Nothing is logged yet. The workout will not be saved.'
              : 'This deletes the ${plural('set', cubit.state.sets.length)} '
                    'logged in this workout.',
          confirmLabel: 'Cancel workout',
          destructive: true,
        );
        if (confirmed && context.mounted) await cubit.discardWorkout();
    }
  }

  Future<void> _finish(BuildContext context, int setCount) async {
    final cubit = context.read<WorkoutCubit>();
    // Leaving a focused set's row is what commits it: unfocus first so a
    // just-typed row makes the save.
    FocusManager.instance.primaryFocus?.unfocus();
    if (setCount == 0) {
      if (await _confirmDiscard(context, noSets: true) && context.mounted) {
        await cubit.discardWorkout();
      }
      return;
    }
    final action = await _showEndOptions(context, setCount);
    if (!context.mounted || action == _EndAction.keepGoing) return;
    if (action == _EndAction.discard) {
      if (await _confirmDiscard(context, noSets: false) && context.mounted) {
        await cubit.discardWorkout();
      }
    } else {
      await cubit.endWorkout();
    }
  }

  Future<_EndAction> _showEndOptions(BuildContext context, int setCount) async {
    return await showFDialog<_EndAction>(
          context: context,
          builder: (dialogContext, _, _) => AppDialog(
            title: 'End workout?',
            titleTrailing: Semantics(
              label: 'Discard workout',
              button: true,
              child: AppIconButton(
                icon: FLucideIcons.trash2,
                tooltip: 'Discard workout',
                color: dialogContext.theme.colors.error,
                onPress: () => Navigator.pop(dialogContext, _EndAction.discard),
              ),
            ),
            message:
                'Log ${plural('set', setCount)} and save this workout to history.',
            actionsGap: 16,
            actions: [
              FButton(
                variant: .outline,
                onPress: () =>
                    Navigator.pop(dialogContext, _EndAction.keepGoing),
                child: const Text('Keep going'),
              ),
              FButton(
                onPress: () => Navigator.pop(dialogContext, _EndAction.save),
                child: const Text('End & save'),
              ),
            ],
          ),
        ) ??
        _EndAction.keepGoing;
  }

  Future<bool> _confirmDiscard(BuildContext context, {required bool noSets}) {
    return showConfirmDialog(
      context,
      title: 'Discard workout?',
      message: noSets
          ? 'No sets have been logged. Do you want to discard this session?'
          : 'This will delete all progress for this session.',
      confirmLabel: 'Discard',
    );
  }
}

enum _EndAction { save, discard, keepGoing }

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
      footer: _AddExerciseRow(onPress: onAdd),
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
    final muted = theme.typography.body.xs.copyWith(
      color: theme.colors.mutedForeground,
    );
    if (isCurrent) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: _CurrentCard(index: index, entry: entry, onOpen: onOpen),
      );
    }
    final Widget leading;
    final Widget subtitle;
    final Widget trailing;
    if (entry.isDone) {
      leading = const _DoneMark();
      final best = _bestSet(entry.sets);
      subtitle = Text(
        best == null
            ? 'Done'
            : 'Best set ${formatWeight(context, best.weight)} × '
                  '${formatReps(best.reps)}',
        style: muted,
      );
      trailing = Text(
        '${entry.workingLogged} of ${entry.planned}',
        style: muted,
      );
    } else {
      leading = SizedBox(
        width: 24,
        child: Text('${index + 1}', textAlign: TextAlign.center, style: muted),
      );
      subtitle = Row(
        children: <Widget>[
          if (entry.planned > 0) ...[
            _Pips(planned: entry.planned, logged: entry.workingLogged),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              _upcomingDetail(entry),
              style: muted,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
      trailing = Icon(
        FLucideIcons.chevronRight,
        size: 18,
        color: theme.colors.mutedForeground,
      );
    }
    return FTappable(
      onPress: onOpen,
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: theme.colors.background,
          border: Border(bottom: BorderSide(color: theme.colors.border)),
        ),
        child: Row(
          children: <Widget>[
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.exercise.name,
                    style: theme.typography.body.sm.copyWith(
                      fontWeight: FontWeight.w600,
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
        ),
      ),
    );
  }

  static String _upcomingDetail(WorkoutEntry entry) {
    if (entry.planned > 0) {
      final targets = [
        for (final set in entry.exercise.sets) SetTarget.fromPlanned(set),
      ];
      return entry.workingLogged > 0
          ? '${entry.workingLogged} of ${entry.planned} sets'
          : setsSummary(targets);
    }
    return entry.sets.isEmpty
        ? 'No sets yet'
        : '${plural('set', entry.sets.length)} logged';
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

/// One dot per planned set, filled for each one logged.
class _Pips extends StatelessWidget {
  const _Pips({required this.planned, required this.logged});

  final int planned;
  final int logged;

  @override
  Widget build(BuildContext context) {
    final accents = TrackerAccents.of(context);
    final empty = context.theme.colors.mutedForeground;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < planned; i++)
          Container(
            width: 10,
            height: 10,
            margin: EdgeInsets.only(right: i == planned - 1 ? 0 : 5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < logged ? accents.live : null,
              border: Border.all(
                color: i < logged ? accents.live : empty,
                width: 1.5,
              ),
            ),
          ),
      ],
    );
  }
}

class _CurrentCard extends StatelessWidget {
  const _CurrentCard({
    required this.index,
    required this.entry,
    required this.onOpen,
  });

  final int index;
  final WorkoutEntry entry;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final accents = TrackerAccents.of(context);
    final muted = theme.typography.body.xs.copyWith(
      color: theme.colors.mutedForeground,
    );
    return FTappable(
      onPress: onOpen,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: theme.colors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accents.live, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                SizedBox(width: 18, child: Text('${index + 1}', style: muted)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.exercise.name,
                    style: theme.typography.body.md.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Row(
                children: <Widget>[
                  _Pips(planned: entry.planned, logged: entry.workingLogged),
                  const SizedBox(width: 8),
                  Text(
                    '${entry.workingLogged} of ${plural('set', entry.planned)}',
                    style: muted,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 0, 12),
              child: _NextSet(entry: entry),
            ),
            AccentButton(label: 'Continue', onPress: onOpen),
          ],
        ),
      ),
    );
  }
}

/// "Next set 30 kg × 10" from the prefill, else the next planned target.
class _NextSet extends StatefulWidget {
  const _NextSet({required this.entry});

  final WorkoutEntry entry;

  @override
  State<_NextSet> createState() => _NextSetState();
}

class _NextSetState extends State<_NextSet> {
  Future<PreviousPerformance?>? _previous;
  int? _loadedFor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(covariant _NextSet oldWidget) {
    super.didUpdateWidget(oldWidget);
    _load();
  }

  void _load() {
    final id = widget.entry.exercise.exerciseId;
    if (_loadedFor == id) return;
    _loadedFor = id;
    _previous = RepositoryScope.maybeOf(context)?.sessions
        .getPreviousPerformance(id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final style = theme.typography.body.xs;
    final prefill = SettingsCubit.maybeOf(context)?.state.prefillSets ?? true;
    return FutureBuilder<PreviousPerformance?>(
      future: _previous,
      builder: (context, snapshot) {
        final entry = widget.entry;
        final index = entry.sets.length;
        final last = entry.sets.isEmpty ? null : entry.sets.last;
        final ghost = ghostForRow(
          index: index,
          previous: prefill ? snapshot.data : null,
          planned: entry.exercise.sets,
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
        final target = index < entry.exercise.sets.length
            ? SetTarget.fromPlanned(entry.exercise.sets[index]).description
            : null;
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
  const _NoExercises({required this.onAdd});

  final VoidCallback onAdd;

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
        const SizedBox(height: 16),
        AccentButton(
          large: true,
          prefix: FLucideIcons.plus,
          label: 'Add exercise',
          onPress: onAdd,
        ),
      ],
    );
  }
}
