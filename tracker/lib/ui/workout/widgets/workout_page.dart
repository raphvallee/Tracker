import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/ui/core/ui/app_dialog.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/core/ui/icon_button.dart';
import 'package:tracker/ui/core/ui/keyboard_inset.dart';
import 'package:tracker/ui/core/ui/max_width.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

import 'exercise_picker_page.dart';
import 'exercise_sets_card.dart';
import 'gym_picker.dart';

class WorkoutPage extends StatelessWidget {
  const WorkoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WorkoutCubit>();
    return BlocListener<WorkoutCubit, WorkoutState>(
      listenWhen: (previous, current) =>
          current.saveError != null && current.saveError != previous.saveError,
      listener: (context, state) => showFToast(
        context: context,
        title: Text(state.saveError!),
        duration: const Duration(seconds: 4),
      ),
      child: CustomScrollView(
        slivers: <Widget>[
          CustomAppBar(context, title: 'Current Workout'),
          BlocSelector<
            WorkoutCubit,
            WorkoutState,
            ({
              bool canRestoreDiscarded,
              bool canRestoreSaved,
              bool isInProgress,
            })
          >(
            selector: (state) => (
              isInProgress: state.isInProgress,
              canRestoreSaved: state.canRestoreSaved(),
              canRestoreDiscarded: state.canRestoreDiscarded(),
            ),
            builder: (context, view) {
              if (view.isInProgress) {
                return SliverToBoxAdapter(
                  child: MaxWidth(
                    child: _InProgressView(
                      onEnd: cubit.endWorkout,
                      onDiscard: cubit.discardWorkout,
                    ),
                  ),
                );
              }
              return SliverFillRemaining(
                hasScrollBody: false,
                child: MaxWidth(
                  child: _IdleView(
                    onStart: () => _startWorkout(context),
                    onRestoreLast: cubit.restoreLastWorkout,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _startWorkout(BuildContext context) async {
    final cubit = context.read<WorkoutCubit>();
    final repo = RepositoryScope.maybeOf(context);
    final gyms = (await repo?.gyms.getAll()) ?? const <Gym>[];
    if (!context.mounted) return;
    final pick = await promptGym(context, gyms);
    if (pick == null) return;
    cubit.startWorkout(gym: pick.gym);
  }
}

class _IdleView extends StatefulWidget {
  const _IdleView({required this.onStart, required this.onRestoreLast});

  final VoidCallback onStart;
  final Future<void> Function() onRestoreLast;

  @override
  State<_IdleView> createState() => _IdleViewState();
}

class _IdleViewState extends State<_IdleView> {
  Timer? _windowTicker;

  @override
  void dispose() {
    _windowTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<WorkoutCubit>().state;
    // The discarded-restore window lapses with wall-clock time, which no cubit
    // state change announces. While the window is live, tick periodically so
    // the restore button disappears on time (and stays away afterwards).
    final windowLive = state.canRestoreSaved() || state.canRestoreDiscarded();
    _windowTicker?.cancel();
    _windowTicker = windowLive
        ? Timer.periodic(const Duration(seconds: 30), (_) {
            if (mounted) setState(() {});
          })
        : null;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: <Widget>[
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(FLucideIcons.dumbbell, size: 48),
                const SizedBox(height: 12),
                const Text('No workout in progress'),
                const SizedBox(height: 16),
                FButton(
                  mainAxisSize: MainAxisSize.min,
                  onPress: widget.onStart,
                  prefix: const Icon(FLucideIcons.play),
                  child: const Text('Start Workout'),
                ),
              ],
            ),
          ),
          if (state.canRestoreSaved() || state.canRestoreDiscarded()) ...[
            FButton(
              mainAxisSize: MainAxisSize.min,
              variant: .outline,
              onPress: () => widget.onRestoreLast(),
              prefix: const Icon(FLucideIcons.rotateCcw),
              child: const Text('Restore last workout'),
            ),
          ],
        ],
      ),
    );
  }
}

enum _WorkoutAction { save, discard, cancel }

class _InProgressView extends StatelessWidget {
  const _InProgressView({required this.onEnd, required this.onDiscard});

  final Future<void> Function() onEnd;
  final Future<void> Function() onDiscard;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<WorkoutCubit, WorkoutState, _WorkoutPresentation>(
      selector: _WorkoutPresentation.fromState,
      builder: (context, presentation) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, keyboardClearanceOf(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _WorkoutHeader(presentation: presentation.header),
            const SizedBox(height: 16),
            for (final (index, entry) in presentation.exercises.indexed)
              ExerciseSetsCard(
                key: presentation.isFree
                    ? ValueKey('free-${entry.exercise.exerciseId}')
                    : ValueKey('plan-${entry.exercise.order}'),
                orderNumber: index,
                exerciseId: entry.exercise.exerciseId,
                exerciseName: entry.exercise.name,
                planned: !presentation.isFree,
                sets: entry.sets,
                plannedSets: entry.exercise.sets,
                onRemove: presentation.isFree
                    ? () => _removeExercise(context, entry)
                    : null,
              ),
            if (presentation.isFree) ...[
              if (presentation.exercises.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Add an exercise to start logging sets.',
                    textAlign: TextAlign.center,
                    style: context.theme.typography.body.sm.copyWith(
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                ),
              FButton(
                variant: .outline,
                onPress: () => _addExercise(context),
                prefix: const Icon(FLucideIcons.plus),
                child: const Text('Add exercise'),
              ),
            ],
            const SizedBox(height: 24),
            FButton(
              variant: .destructive,
              onPress: () {
                // Leaving the focused set's row is what commits it, so
                // unfocus before the end flow - otherwise a just-typed row
                // would miss the save.
                FocusManager.instance.primaryFocus?.unfocus();
                _confirmEnd(
                  context,
                  presentation.setCount,
                  onDiscard: onDiscard,
                );
              },
              prefix: const Icon(FLucideIcons.squareStop),
              child: const Text('End Workout'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addExercise(BuildContext context) async {
    // Leaving a typed row is what logs it: do that before the picker covers
    // the card.
    FocusManager.instance.primaryFocus?.unfocus();
    final exercise = await pushTo<Exercise>(
      context,
      const ExercisePickerPage(),
    );
    if (exercise == null || !context.mounted) return;
    final added = context.read<WorkoutCubit>().addExercise(
      exerciseId: exercise.id,
      name: exercise.title,
    );
    if (!added) {
      showFToast(
        context: context,
        title: Text('${exercise.title} is already in this workout'),
        duration: const Duration(seconds: 3),
      );
    }
  }

  Future<void> _removeExercise(
    BuildContext context,
    _ExerciseEntry entry,
  ) async {
    if (entry.sets.isNotEmpty) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Remove ${entry.exercise.name}?',
        message:
            'This will delete its ${plural('set', entry.sets.length)} from '
            'this workout.',
        confirmLabel: 'Remove',
        destructive: true,
      );
      if (!confirmed || !context.mounted) return;
    }
    context.read<WorkoutCubit>().removeExercise(entry.exercise.exerciseId);
  }

  Future<void> _confirmEnd(
    BuildContext context,
    int setCount, {
    required Future<void> Function() onDiscard,
  }) async {
    if (setCount == 0) {
      final confirmDiscard = await _showDiscardConfirmation(
        context,
        noSets: true,
      );
      if (confirmDiscard && context.mounted) {
        await onDiscard();
      }
      return;
    }

    final action = await _showEndOptionsDialog(context, setCount);
    if (!context.mounted || action == _WorkoutAction.cancel) return;

    if (action == _WorkoutAction.discard) {
      final confirmDiscard = await _showDiscardConfirmation(
        context,
        noSets: false,
      );
      if (confirmDiscard && context.mounted) {
        await onDiscard();
      }
    } else if (action == _WorkoutAction.save) {
      await onEnd();
    }
  }

  Future<_WorkoutAction> _showEndOptionsDialog(
    BuildContext context,
    int setCount,
  ) async {
    return await showFDialog<_WorkoutAction>(
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
                onPress: () =>
                    Navigator.pop(dialogContext, _WorkoutAction.discard),
              ),
            ),
            message:
                'Log ${plural('set', setCount)} and save this workout to history.',
            actionsGap: 16,
            actions: [
              FButton(
                variant: .outline,
                onPress: () =>
                    Navigator.pop(dialogContext, _WorkoutAction.cancel),
                child: const Text('Keep going'),
              ),
              FButton(
                onPress: () =>
                    Navigator.pop(dialogContext, _WorkoutAction.save),
                child: const Text('End & save'),
              ),
            ],
          ),
        ) ??
        _WorkoutAction.cancel;
  }

  Future<bool> _showDiscardConfirmation(
    BuildContext context, {
    bool noSets = false,
  }) {
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

typedef _ExerciseEntry = ({PlanExercise exercise, List<ActiveSet> sets});

class _WorkoutPresentation {
  const _WorkoutPresentation({
    required this.header,
    required this.isFree,
    required this.exercises,
    required this.setCount,
  });

  final _WorkoutHeaderData header;

  /// A free workout has no split day behind it: its exercise cards are the
  /// ones the user added along the way.
  final bool isFree;
  final List<_ExerciseEntry> exercises;
  final int setCount;

  static _WorkoutPresentation fromState(WorkoutState state) {
    final isFree = state.planTitle == null;
    final grouped = state.setsByExercise;
    final listed = {for (final exercise in state.plan) exercise.exerciseId};
    return _WorkoutPresentation(
      header: _WorkoutHeaderData.fromState(state),
      isFree: isFree,
      exercises: [
        for (final exercise in state.plan)
          (exercise: exercise, sets: grouped[exercise.exerciseId] ?? const []),
        // Free sets without a card of their own (sessions saved before free
        // workouts kept their exercises) still get one, in logged order.
        if (isFree)
          for (final MapEntry(key: id, value: sets) in grouped.entries)
            if (!listed.contains(id))
              (
                exercise: PlanExercise(
                  exerciseId: id,
                  name: sets.first.exerciseName,
                ),
                sets: sets,
              ),
      ],
      setCount: state.sets.length,
    );
  }
}

class _WorkoutHeaderData {
  const _WorkoutHeaderData({
    this.planTitle,
    this.gymName,
    this.startTime,
    required this.setCount,
    required this.workingVolume,
  });

  final String? planTitle;
  final String? gymName;
  final DateTime? startTime;
  final int setCount;
  final double workingVolume;

  static _WorkoutHeaderData fromState(WorkoutState state) => _WorkoutHeaderData(
    planTitle: state.planTitle,
    gymName: state.gymName,
    startTime: state.startTime,
    setCount: state.sets.length,
    workingVolume: state.workingVolume,
  );
}

class _WorkoutHeader extends StatelessWidget {
  const _WorkoutHeader({required this.presentation});

  final _WorkoutHeaderData presentation;

  @override
  Widget build(BuildContext context) {
    final started = presentation.startTime;
    final working = presentation.workingVolume;
    return FCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  FLucideIcons.footprints,
                  color: context.theme.colors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    presentation.planTitle ?? 'Free workout',
                    style: context.theme.typography.body.xl.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (presentation.gymName != null)
              Text('${presentation.gymName} · ${_fmtTime(started)}')
            else
              Text(_fmtTime(started)),
            const SizedBox(height: 8),
            Text(
              '${plural('set', presentation.setCount)} · ${formatWeight(context, working)} working volume',
              style: context.theme.typography.body.md,
            ),
          ],
        ),
      ),
    );
  }

  String _fmtTime(DateTime? dt) {
    if (dt == null) return '';
    final t = dt.toLocal();
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return 'Started at $hh:$mm';
  }
}
