import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/split_draft.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/routing/tab_navigation.dart';
import 'package:tracker/ui/core/ui/accent_button.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/core/ui/item_card.dart';
import 'package:tracker/ui/core/ui/relative_dates.dart';
import 'package:tracker/ui/core/ui/sheet_surface.dart';
import 'package:tracker/ui/splits/view_models/split_drafts_cubit.dart';
import 'package:tracker/ui/splits/widgets/split_day_editor_page.dart';

import 'start_workout.dart';

/// What holding a split day shows: its exercises and targets, a Start button
/// and a way to edit the day in the Splits tab.
Future<void> showDayPreview(
  BuildContext context, {
  required WorkoutSplit split,
  required int dayIndex,
  required Map<int, String> names,
  DateTime? lastDone,
}) {
  return showFSheet<void>(
    context: context,
    side: .btt,
    useRootNavigator: true,
    mainAxisMaxRatio: 0.85,
    builder: (sheetContext) => _DayPreview(
      split: split,
      dayIndex: dayIndex,
      names: names,
      lastDone: lastDone,
      // The sheet lives on the root navigator: start and edit from the
      // context that opened it, which can reach the tab navigators.
      hostContext: context,
    ),
  );
}

/// Opens the saved day at [savedDayIndex] in the Splits tab: the day it
/// became in [split]'s draft, or the split list when the draft removed it.
void openDayInSplits(
  BuildContext context,
  WorkoutSplit split,
  int savedDayIndex,
) {
  final drafts = context.read<SplitDraftsCubit>();
  final draft = drafts.draftOf(split, fallback: defaultSetTargetOf(context));
  final dayIndex = draft.days.indexWhere((day) => day.origin == savedDayIndex);
  if (dayIndex < 0) {
    HomePageSingleton().changeTab(TabName.splits);
    return;
  }
  HomePageSingleton().pushInTab(
    TabName.splits,
    slideRoute(
      context,
      SplitDayEditorPage(splitId: split.id, dayIndex: dayIndex),
    ),
  );
}

class _DayPreview extends StatelessWidget {
  const _DayPreview({
    required this.split,
    required this.dayIndex,
    required this.names,
    required this.lastDone,
    required this.hostContext,
  });

  final WorkoutSplit split;
  final int dayIndex;
  final Map<int, String> names;
  final DateTime? lastDone;
  final BuildContext hostContext;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final day = split.splitDays[dayIndex];
    final plan = SplitDraft.fromSplit(
      split,
      fallback: defaultSetTargetOf(context),
    ).days[dayIndex].exercises;
    final last = lastDone;
    return SheetSurface(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            day.title,
            style: theme.typography.body.xl.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            last == null
                ? '${split.title}, not done yet'
                : '${split.title}, last done ${dayLabel(last)}',
            style: theme.typography.body.xs.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: 12),
          if (plan.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No exercises yet. Add some in Splits.',
                style: theme.typography.body.sm.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ),
          if (plan.isNotEmpty)
            ItemCard(
              divider: .full,
              children: <FItem>[
                for (final (i, exercise) in plan.indexed)
                  FItem(
                    prefix: SizedBox(
                      width: 18,
                      child: Text(
                        '${i + 1}',
                        textAlign: TextAlign.right,
                        style: theme.typography.body.xs.copyWith(
                          color: theme.colors.mutedForeground,
                        ),
                      ),
                    ),
                    title: Text(
                      names[exercise.exerciseId] ??
                          'Exercise ${exercise.exerciseId}',
                    ),
                    subtitle: Text(setsSummary(exercise.sets)),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          AccentButton(
            large: true,
            prefix: FLucideIcons.play,
            label: 'Start ${day.title}',
            onPress: () {
              Navigator.of(context).pop();
              startSplitDay(
                hostContext,
                split: split,
                dayIndex: dayIndex,
                names: names,
              );
            },
          ),
          const SizedBox(height: 6),
          FButton(
            variant: .ghost,
            prefix: const Icon(FLucideIcons.pencil),
            onPress: () {
              Navigator.of(context).pop();
              openDayInSplits(hostContext, split, dayIndex);
            },
            child: const Text('Edit in Splits'),
          ),
        ],
      ),
    );
  }
}
