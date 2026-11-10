import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tracker/domain/models/effort_scale.dart';
import 'package:tracker/domain/models/number_entry.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/settings/widgets/settings_list.dart';

const numberEntryOptions = <SettingOption<NumberEntry>>[
  SettingOption(
    NumberEntry.keypad,
    'Keypad',
    'A big keypad opens inside the app, with Next and Log keys.',
  ),
  SettingOption(
    NumberEntry.phoneKeyboard,
    'Phone keyboard',
    "Your phone's number keyboard, with Next and Log above it.",
  ),
  SettingOption(
    NumberEntry.steppers,
    'Steppers',
    'Change a number with - and +, or drag it up or down. Hold it to '
        'type.',
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
    '${state.effortScale.label}';

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
          ],
        );
      },
    );
  }
}
