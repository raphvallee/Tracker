import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/data/services/app_log.dart';
import 'package:tracker/data/services/gym_factors.dart';
import 'package:tracker/domain/models/effort_scale.dart';
import 'package:tracker/domain/models/number_entry.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/settings/widgets/settings_list.dart';

const numberEntryOptions = <SettingOption<NumberEntry>>[
  SettingOption(
    NumberEntry.keypadSteppers,
    'Keypad and steppers',
    'The keypad, with - and + beside the digits. Hold one to repeat, or '
        'drag along them.',
  ),
  SettingOption(
    NumberEntry.keypadRuler,
    'Keypad and ruler',
    'The keypad, with a ruler on top: drag it to slide the number, or tap '
        '- and + at its ends.',
  ),
  SettingOption(
    NumberEntry.phoneKeyboard,
    'Phone keyboard',
    "Your phone's number keyboard, with Next and Log above it.",
  ),
];

const effortScaleOptions = <SettingOption<EffortScale>>[
  SettingOption(
    EffortScale.rpe,
    'RPE',
    'Rate of perceived exertion: how hard the set was. 10 is a set taken '
        'to failure.',
  ),
  SettingOption(
    EffortScale.rir,
    'RIR',
    'Reps in reserve: how many more reps you had in you. 0 is a set taken '
        'to failure.',
  ),
];

/// One line on the Settings page saying how sets are logged.
String workoutSummary(SettingsState state) =>
    '${optionOf(numberEntryOptions, state.numberEntry).label} entry, '
    '${state.prefillSets ? 'prefilled sets' : 'no prefill'}, '
    '${state.effortScale.label}'
    '${state.effectiveReps ? ', effective reps' : ''}';

/// Effective reps in [scale]'s words: what a rated set counts as.
String effectiveRepsExample(EffortScale scale) => scale == EffortScale.rpe
    ? '8 reps at RPE 7 count as 11'
    : '8 reps with 3 in reserve count as 11';

/// Turns effective reps on or off, then works the gyms' machine factors out
/// again the new way, in the background.
void _setEffectiveReps(BuildContext context, bool value) {
  context.read<SettingsCubit>().setEffectiveReps(value);
  final repo = RepositoryScope.maybeOf(context);
  if (repo != null) unawaited(_refreshGymFactors(repo, value));
}

Future<void> _refreshGymFactors(
  TrackerRepository repo,
  bool effectiveReps,
) async {
  try {
    await refreshGymFactors(repo, effectiveReps: effectiveReps);
  } catch (error, stackTrace) {
    AppLog.error('settings-gym-factors', error, stackTrace);
  }
}

/// How sets are logged during a workout.
class WorkoutSettingsPage extends StatelessWidget {
  const WorkoutSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SettingsCubit>();
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final heavy = state.unit.heavyWeightThreshold;
        return SettingsScaffold(
          title: 'Workout',
          sections: <Widget>[
            SettingsSection(
              title: 'Logging sets',
              children: [
                SettingsChoiceItem<NumberEntry>(
                  title: 'Number entry',
                  description: 'What opens when you tap a weight or reps',
                  options: numberEntryOptions,
                  value: state.numberEntry,
                  onChanged: cubit.setNumberEntry,
                  sheetNote: 'Also used for planned sets in Splits.',
                ),
                SettingsSwitchItem(
                  title: 'Prefill sets',
                  description:
                      "Show last time's numbers in grey, ready to log in one "
                      'tap',
                  value: state.prefillSets,
                  onChanged: cubit.setPrefillSets,
                ),
                SettingsChoiceItem<EffortScale>(
                  title: 'Effort rating',
                  description: 'How you rate how hard each set was',
                  options: effortScaleOptions,
                  value: state.effortScale,
                  onChanged: cubit.setEffortScale,
                  sheetNote:
                      'Switching keeps every rating you logged: RIR is 10 '
                      'minus RPE.',
                ),
              ],
            ),
            SettingsSection(
              title: 'Checks',
              children: [
                SettingsSwitchItem(
                  title: 'Confirm heavy weights',
                  description:
                      'Ask before logging more than '
                      '${formatDecimal(heavy)} ${state.unit.symbol}, in case '
                      'of a typo',
                  value: state.showHeavyWeightWarning,
                  onChanged: cubit.setShowHeavyWeightWarning,
                ),
              ],
            ),
            SettingsSection(
              title: 'Other gyms',
              footer:
                  'Used where machine and cable weights carry to another '
                  'gym: their factors, and the sets after one rated very '
                  'easy or taken to failure.',
              children: [
                SettingsSwitchItem(
                  title: 'Effective reps',
                  description:
                      'Rated sets count the reps left in them: '
                      '${effectiveRepsExample(state.effortScale)}',
                  value: state.effectiveReps,
                  onChanged: (value) => _setEffectiveReps(context, value),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
