import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/settings/widgets/settings_list.dart';
import 'package:tracker/ui/splits/widgets/set_target_sheet.dart';
import 'package:tracker/ui/workout/widgets/start_workout.dart';

/// One line on the Settings page saying what new exercises start with.
String splitsSummary(SettingsState state) =>
    'New exercises start at ${defaultSetTarget(state).description}';

/// How splits are planned.
class SplitsSettingsPage extends StatelessWidget {
  const SplitsSettingsPage({super.key});

  Future<void> _editTarget(BuildContext context, SettingsState state) async {
    final cubit = context.read<SettingsCubit>();
    final result = await showSetTargetSheet(
      context,
      title: 'Rep target',
      subtitle: 'For exercises you add to a split day',
      sets: [defaultSetTarget(state)],
      index: 0,
      allowWarmup: false,
      saveOnClose: true,
    );
    if (result?.target case final target?) cubit.setDefaultSetTarget(target);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) => SettingsScaffold(
        title: 'Splits',
        sections: <Widget>[
          SettingsSection(
            title: 'New exercises',
            footer:
                'An exercise you add to a split day starts with one set at '
                'this target. Each set you add after it copies the one '
                'before.',
            children: [
              SettingsValueItem(
                title: 'Rep target',
                value: defaultSetTarget(state).description,
                onPress: () => _editTarget(context, state),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
