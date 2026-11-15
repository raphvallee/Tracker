import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/ui/core/themes/accents.dart';
import 'package:tracker/ui/core/ui/accent_button.dart';
import 'package:tracker/ui/core/ui/app_dialog.dart';
import 'package:tracker/ui/core/ui/icon_button.dart';
import 'package:tracker/ui/core/ui/item_card.dart';
import 'package:tracker/ui/core/ui/sheet_surface.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

import 'workout_entries.dart';

/// What the finish sheet closes with.
sealed class _FinishChoice {
  const _FinishChoice();
}

class _Save extends _FinishChoice {
  const _Save();
}

class _Discard extends _FinishChoice {
  const _Discard();
}

class _GoTo extends _FinishChoice {
  const _GoTo(this.exerciseId);

  final int exerciseId;
}

/// Finish, from the overview or an exercise page: a sheet sums up what gets
/// saved (length, sets, weight lifted) and lists the exercises still open,
/// each a tap away through [openExercise]; Save workout writes it to
/// history. Discarding is the quiet trash icon in the title row, asked
/// again before anything goes. With nothing logged there is nothing to
/// save, so it offers to discard the workout.
Future<void> finishWorkout(
  BuildContext context, {
  required ValueChanged<int> openExercise,
}) async {
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
  final choice = await showFSheet<_FinishChoice>(
    context: context,
    side: .btt,
    useRootNavigator: true,
    mainAxisMaxRatio: 0.85,
    builder: (_) => const _FinishSheet(),
  );
  if (!context.mounted) return;
  switch (choice) {
    case _Save():
      await cubit.endWorkout();
    case _Discard():
      if (await confirmDiscardWorkout(context) && context.mounted) {
        await cubit.discardWorkout();
      }
    case _GoTo(:final exerciseId):
      openExercise(exerciseId);
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

class _FinishSheet extends StatelessWidget {
  const _FinishSheet();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return BlocBuilder<WorkoutCubit, WorkoutState>(
      builder: (context, state) {
        if (!state.isInProgress) return const SizedBox.shrink();
        final open = [
          for (final entry in workoutEntries(state))
            if (entry.hasWorkLeft) entry,
        ];
        final working = state.sets.where((set) => !set.isWarmup).toList();
        final volume = working.fold<double>(
          0,
          (sum, set) => sum + set.weight * set.reps,
        );
        final length = DateTime.now().difference(
          state.startTime ?? DateTime.now(),
        );
        void close(_FinishChoice? choice) => Navigator.of(context).pop(choice);
        return SheetSurface(
          scrollable: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      state.planTitle == null
                          ? 'Finish workout?'
                          : 'Finish ${state.planTitle}?',
                      style: theme.typography.body.lg.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  // Rarely wanted: a quiet icon up top, away from the thumb,
                  // and it still asks before anything goes.
                  AppIconButton(
                    icon: FLucideIcons.trash2,
                    tooltip: 'Discard workout',
                    color: theme.colors.mutedForeground,
                    onPress: () => close(const _Discard()),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(child: _Stat(stat: _lengthStat(length))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Stat(
                      stat: (
                        value: '${working.length}',
                        label: working.length == 1
                            ? 'set logged'
                            : 'sets logged',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Stat(
                      stat: (
                        value: groupedNumber(displayWeightOf(context, volume)),
                        label: '${weightUnitOf(context).symbol} lifted',
                      ),
                    ),
                  ),
                ],
              ),
              if (open.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Still open',
                  style: theme.typography.body.sm.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ItemCard(
                  children: <FItemMixin>[
                    for (final entry in open)
                      FItem(
                        title: Text(entry.exercise.name),
                        subtitle: Text(_openLabel(entry)),
                        suffix: const _GoToTag(),
                        onPress: () => close(_GoTo(entry.exercise.exerciseId)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              AccentButton(
                large: true,
                label: 'Save workout',
                onPress: () => close(const _Save()),
              ),
              const SizedBox(height: 4),
              FButton(
                variant: .ghost,
                onPress: () => close(null),
                child: const Text('Keep going'),
              ),
            ],
          ),
        );
      },
    );
  }
}

typedef _StatValue = ({String value, String label});

/// The workout's length as a stat: "58 minutes", from an hour "1:12 hours".
_StatValue _lengthStat(Duration length) {
  final minutes = length.isNegative ? 0 : length.inMinutes;
  if (minutes < 60) {
    return (value: '$minutes', label: minutes == 1 ? 'minute' : 'minutes');
  }
  final rest = (minutes % 60).toString().padLeft(2, '0');
  return (value: '${minutes ~/ 60}:$rest', label: 'hours');
}

/// How much of an open exercise is left: "2 of 3 sets left", "Not started".
String _openLabel(WorkoutEntry entry) {
  if (entry.sets.isEmpty) return 'Not started';
  final left = entry.planned - entry.workingLogged;
  return '$left of ${entry.planned} sets left';
}

/// One number of the summary over what it counts, in an outlined tile.
class _Stat extends StatelessWidget {
  const _Stat({required this.stat});

  final _StatValue stat;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // A long workout or a big total shrinks to fit a narrow tile.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              stat.value,
              maxLines: 1,
              style: theme.typography.body.xl.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Text(
            stat.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.body.xs.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

/// The blue pill on an open exercise's row; the whole row opens it.
class _GoToTag extends StatelessWidget {
  const _GoToTag();

  @override
  Widget build(BuildContext context) {
    final live = TrackerAccents.of(context).live;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: live),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Go to',
        style: context.theme.typography.body.xs.copyWith(
          color: live,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
