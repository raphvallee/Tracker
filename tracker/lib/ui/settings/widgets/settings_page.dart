import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/settings/widgets/gyms_page.dart';
import 'package:tracker/ui/settings/widgets/settings_list.dart';
import 'package:tracker/ui/settings/widgets/splits_settings_page.dart';
import 'package:tracker/ui/settings/widgets/workout_settings_page.dart';

const weightUnitOptions = <SettingOption<WeightUnit>>[
  SettingOption(WeightUnit.kilograms, 'Kilograms', 'Weights show in kg.'),
  SettingOption(WeightUnit.pounds, 'Pounds', 'Weights show in lb.'),
];

/// What the gyms row says: the primary gym first, then how many more.
String gymsSummary(List<Gym> gyms) {
  if (gyms.isEmpty) return 'Add the gyms you train at';
  final primary = gyms.firstWhere((g) => g.isPrimary, orElse: () => gyms.first);
  final others = gyms.length - 1;
  return others == 0 ? primary.name : '${primary.name} and $others more';
}

/// The settings home: one row per part of the app that has settings, named
/// and iconed like its tab, each saying what is set inside; then the
/// settings for the whole app.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  StreamSubscription<List<Gym>>? _gymsSubscription;
  List<Gym> _gyms = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // RepositoryScope is an inherited widget, so read it after initState.
    // The first read is synchronous so the row never shows "no gyms" while
    // the watcher's first event is on its way.
    if (_gymsSubscription != null) return;
    final gyms = RepositoryScope.maybeOf(context)?.gyms;
    if (gyms == null) return;
    _gyms = gyms.getAllSync();
    _gymsSubscription = gyms.watchAll().listen(
      (all) => setState(() => _gyms = all),
    );
  }

  @override
  void dispose() {
    _gymsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SettingsCubit>();
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) => SettingsScaffold(
        title: 'Settings',
        sections: <Widget>[
          SettingsSection(
            children: [
              SettingsLinkItem(
                icon: FLucideIcons.dumbbell,
                title: 'Workout',
                summary: workoutSummary(state),
                onPress: () => pushTo(context, const WorkoutSettingsPage()),
              ),
              SettingsLinkItem(
                icon: FLucideIcons.notebookText,
                title: 'Splits',
                summary: splitsSummary(state),
                onPress: () => pushTo(context, const SplitsSettingsPage()),
              ),
              SettingsLinkItem(
                icon: FLucideIcons.mapPin,
                title: 'Gyms',
                summary: gymsSummary(_gyms),
                onPress: () => pushTo(context, const GymsPage()),
              ),
            ],
          ),
          SettingsSection(
            title: 'General',
            children: [
              SettingsChoiceItem<WeightUnit>(
                title: 'Weight unit',
                options: weightUnitOptions,
                value: state.unit,
                onChanged: cubit.setUnit,
                sheetNote:
                    'Logs are kept in kg and converted to show, so switching '
                    'never changes a logged weight.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
