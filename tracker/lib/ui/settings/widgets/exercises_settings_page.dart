import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tracker/domain/models/exercises_layout.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/settings/widgets/settings_list.dart';

const exercisesLayoutOptions = <SettingOption<ExercisesLayout>>[
  SettingOption(
    ExercisesLayout.rows,
    'List of groups',
    'Recently trained on top, then a row per muscle group with a ring for '
        'how many of its exercises are in your split, then a row per day of '
        'your split.',
  ),
  SettingOption(
    ExercisesLayout.tiles,
    'Tiles by muscle',
    'A tile per group with a bar for each muscle, so one your split leaves '
        'out stands out. Sort by muscle, split day, equipment or recent.',
  ),
  SettingOption(
    ExercisesLayout.openTiles,
    'Tiles that open',
    'Recently trained on top, then a tile per muscle group or split day '
        'that opens its exercises right below it, without leaving the page.',
  ),
];

/// One line on the Settings page saying how the library is laid out.
String exercisesSummary(SettingsState state) =>
    optionOf(exercisesLayoutOptions, state.exercisesLayout).label;

/// How the Exercises tab shows the library.
class ExercisesSettingsPage extends StatelessWidget {
  const ExercisesSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SettingsCubit>();
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) => SettingsScaffold(
        title: 'Exercises',
        sections: <Widget>[
          SettingsSection(
            title: 'Library',
            footer:
                'Rings and bars count the exercises your current split plans, '
                'on any of its days. Change the current split in the Splits '
                'tab.',
            children: [
              SettingsChoiceItem<ExercisesLayout>(
                title: 'Layout',
                description: 'How the Exercises tab sorts the library',
                options: exercisesLayoutOptions,
                value: state.exercisesLayout,
                onChanged: cubit.setExercisesLayout,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
