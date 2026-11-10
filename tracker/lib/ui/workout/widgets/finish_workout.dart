import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:tracker/ui/core/ui/accent_button.dart';
import 'package:tracker/ui/core/ui/app_dialog.dart';
import 'package:tracker/ui/core/ui/sheet_surface.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

import 'workout_entries.dart';

enum _FinishAction { save, discard }

/// Finish, from the overview or an exercise page: a sheet says what gets
/// saved and which planned sets are still open, then Save workout writes it
/// to history; Discard workout throws it away after asking. With nothing
/// logged there is nothing to save, so it offers to discard the workout.
Future<void> finishWorkout(BuildContext context) async {
  final cubit = context.read<WorkoutCubit>();
  // Leaving a focused set's row is what commits it: unfocus first, and let
  // that commit land, so a just-typed row makes the save.
  FocusManager.instance.primaryFocus?.unfocus();
  await WidgetsBinding.instance.endOfFrame;
  if (!context.mounted || !cubit.state.isInProgress) return;
  if (cubit.state.sets.isEmpty) {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Discard workout?',
      message: 'Nothing is logged yet, so there is nothing to save.',
      confirmLabel: 'Discard workout',
    );
    if (confirmed && context.mounted) await cubit.discardWorkout();
    return;
  }
  final action = await showFSheet<_FinishAction>(
    context: context,
    side: .btt,
    useRootNavigator: true,
    mainAxisMaxRatio: 0.85,
    builder: (_) => const _FinishSheet(),
  );
  if (!context.mounted) return;
  switch (action) {
    case _FinishAction.save:
      await cubit.endWorkout();
    case _FinishAction.discard:
      if (await confirmDiscardWorkout(context) && context.mounted) {
        await cubit.discardWorkout();
      }
    case null:
      break;
  }
}

/// Asks before a running workout is thrown away, saying what goes with it.
Future<bool> confirmDiscardWorkout(BuildContext context) {
  final sets = context.read<WorkoutCubit>().state.sets.length;
  return showConfirmDialog(
    context,
    title: 'Discard workout?',
    message: sets == 0
        ? 'Nothing is logged yet. The workout will not be saved.'
        : 'This deletes the ${plural('set', sets)} logged in this workout.',
    confirmLabel: 'Discard workout',
    destructive: true,
  );
}

/// "12 min", "1 h 5 min".
String _workoutLength(Duration elapsed) {
  final minutes = elapsed.isNegative ? 0 : elapsed.inMinutes;
  if (minutes < 1) return 'under a minute';
  if (minutes < 60) return '$minutes min';
  final rest = minutes % 60;
  return rest == 0 ? '${minutes ~/ 60} h' : '${minutes ~/ 60} h $rest min';
}

class _FinishSheet extends StatelessWidget {
  const _FinishSheet();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return BlocBuilder<WorkoutCubit, WorkoutState>(
      builder: (context, state) {
        if (!state.isInProgress) return const SizedBox.shrink();
        final entries = workoutEntries(state);
        final progress = plannedProgress(entries);
        final left = progress.total - progress.done;
        final length = _workoutLength(
          DateTime.now().difference(state.startTime ?? DateTime.now()),
        );
        final open = [
          for (final entry in entries)
            if (entry.planned > 0 && !entry.isDone) entry.exercise.name,
        ];
        return SheetSurface(
          scrollable: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                state.planTitle == null
                    ? 'Finish workout?'
                    : 'Finish ${state.planTitle}?',
                style: theme.typography.body.lg.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                progress.total > 0
                    ? '${progress.done} of '
                          '${plural('set', progress.total)} logged in '
                          '$length.'
                    : '${plural('set', state.sets.length)} logged in '
                          '$length.',
                style: theme.typography.body.sm,
              ),
              if (left > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colors.muted,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        left == 1
                            ? '1 planned set is not done.'
                            : '$left planned sets are not done.',
                        style: theme.typography.body.sm.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        open.join(', '),
                        style: theme.typography.body.xs.copyWith(
                          color: theme.colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              AccentButton(
                large: true,
                label: 'Save workout',
                onPress: () => Navigator.of(context).pop(_FinishAction.save),
              ),
              const SizedBox(height: 8),
              FButton(
                variant: .outline,
                onPress: () => Navigator.of(context).pop(),
                child: const Text('Keep going'),
              ),
              const SizedBox(height: 4),
              FButton(
                variant: .ghost,
                onPress: () => Navigator.of(context).pop(_FinishAction.discard),
                prefix: Icon(
                  FLucideIcons.trash2,
                  color: theme.colors.destructive,
                ),
                child: Text(
                  'Discard workout',
                  style: TextStyle(color: theme.colors.destructive),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
