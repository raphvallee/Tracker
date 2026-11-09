import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/number_entry.dart';
import 'package:tracker/domain/models/rep_mode.dart';
import 'package:tracker/domain/models/weight_unit.dart';

import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/core/ui/keyboard_inset.dart';
import 'package:tracker/ui/core/ui/max_width.dart';
import 'package:tracker/ui/settings/widgets/gyms_page.dart';
import 'package:tracker/ui/settings/widgets/rep_defaults_dialogs.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';

const EdgeInsets _kSettingsRowPadding = EdgeInsets.symmetric(
  horizontal: 16,
  vertical: 6,
);

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: <Widget>[
        CustomAppBar(context, title: 'Settings'),
        SliverFillRemaining(
          child: BlocBuilder<SettingsCubit, SettingsState>(
            builder: (context, state) => MaxWidth(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  0,
                  12,
                  0,
                  keyboardClearanceOf(context),
                ),
                children: <Widget>[
                  _buildSettingsMenuItem(
                    context,
                    icon: FLucideIcons.dumbbell,
                    title: 'Gyms',
                    subtitle: 'Manage gyms and weight multipliers',
                    onTap: () => pushTo(context, const GymsPage()),
                  ),
                  _buildSettingsDropdownRow(
                    context,
                    icon: FLucideIcons.scale,
                    title: 'Units',
                    subtitle: 'Set your preferred weight unit',
                    value: state.unit,
                    onChanged: (unit) {
                      context.read<SettingsCubit>().setUnit(unit);
                    },
                  ),
                  _buildSwitchRow(
                    context,
                    icon: FLucideIcons.bell,
                    title: 'Notifications',
                    subtitle:
                        'Allow workout reminders and progress notifications',
                    value: state.notificationsEnabled,
                    onChanged: context
                        .read<SettingsCubit>()
                        .setNotificationsEnabled,
                  ),
                  _buildSwitchRow(
                    context,
                    icon: FLucideIcons.shield,
                    title: 'Privacy & Security',
                    subtitle: 'Allow anonymous analytics to improve the app',
                    value: state.analyticsEnabled,
                    onChanged: context
                        .read<SettingsCubit>()
                        .setAnalyticsEnabled,
                  ),
                  _sectionTitle(context, 'Logging sets'),
                  _buildSwitchRow(
                    context,
                    icon: FLucideIcons.clipboardPaste,
                    title: 'Prefill sets',
                    subtitle:
                        "Last session's values or the plan's target reps, "
                        'logged with one tap',
                    value: state.prefillSets,
                    onChanged: context.read<SettingsCubit>().setPrefillSets,
                  ),
                  Padding(
                    padding: _kSettingsRowPadding,
                    child: FCard(
                      child: FItem(
                        prefix: Icon(
                          FLucideIcons.grid3x3,
                          color: context.theme.colors.primary,
                        ),
                        title: const Text('Number entry'),
                        subtitle: Text(
                          'What opens when you tap a weight or reps',
                          style: context.theme.typography.body.xs.copyWith(
                            color: context.theme.colors.mutedForeground,
                          ),
                        ),
                        suffix: _MenuSelect<NumberEntry>(
                          options: const {
                            'Keypad': NumberEntry.keypad,
                            'Phone keyboard': NumberEntry.phoneKeyboard,
                            'Steppers': NumberEntry.steppers,
                          },
                          value: state.numberEntry,
                          onChanged: context
                              .read<SettingsCubit>()
                              .setNumberEntry,
                        ),
                      ),
                    ),
                  ),
                  _WorkoutDefaultsSection(state: state),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsDropdownRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required WeightUnit value,
    required ValueChanged<WeightUnit> onChanged,
  }) {
    return Padding(
      padding: _kSettingsRowPadding,
      child: FCard(
        child: FItem(
          prefix: Icon(icon, color: context.theme.colors.primary),
          title: Text(title),
          subtitle: Text(
            subtitle,
            style: context.theme.typography.body.xs.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
          suffix: _MenuSelect<WeightUnit>(
            options: {for (final unit in WeightUnit.values) unit.symbol: unit},
            value: value,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
    child: Text(
      title,
      style: context.theme.typography.body.md.copyWith(
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _buildSettingsMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: _kSettingsRowPadding,
      child: FCard(
        child: FItem(
          prefix: Icon(icon, color: context.theme.colors.primary),
          title: Text(title),
          subtitle: Text(subtitle),
          suffix: const Icon(FLucideIcons.chevronRight, size: 16),
          onPress: onTap,
        ),
      ),
    );
  }

  Widget _buildSwitchRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: _kSettingsRowPadding,
      child: FCard(
        child: FItem(
          prefix: Icon(icon, color: context.theme.colors.primary),
          title: Text(title),
          subtitle: Text(subtitle),
          suffix: FSwitch(value: value, onChange: onChanged),
          onPress: () => onChanged(!value),
        ),
      ),
    );
  }
}

/// A dropdown for a settings row: a button showing the selected option that
/// opens a menu of the options. Unlike [FSelect] it builds no text field,
/// which made Settings' first frame several times slower.
class _MenuSelect<T> extends StatelessWidget {
  const _MenuSelect({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final Map<String, T> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = options.entries.firstWhere(
      (option) => option.value == value,
    );
    return FPopoverMenu.tiles(
      menuAnchor: .topRight,
      childAnchor: .bottomRight,
      // Built when the menu opens, not with the page.
      menuBuilder: (context, controller, _) => [
        .group(
          children: [
            for (final MapEntry(key: label, value: option) in options.entries)
              .tile(
                title: Text(label),
                selected: option == value,
                suffix: option == value
                    ? const Icon(FLucideIcons.check, size: 16)
                    : null,
                onPress: () {
                  controller.hide();
                  if (option != value) onChanged(option);
                },
              ),
          ],
        ),
      ],
      builder: (_, controller, _) => FButton(
        variant: .outline,
        mainAxisSize: .min,
        onPress: controller.toggle,
        suffix: const Icon(FLucideIcons.chevronDown, size: 16),
        child: Text(selected.key),
      ),
    );
  }
}

class _WorkoutDefaultsSection extends StatelessWidget {
  const _WorkoutDefaultsSection({required this.state});

  final SettingsState state;

  Future<void> _editReps(BuildContext context) async {
    final cubit = context.read<SettingsCubit>();
    final reps = await editDefaultRepsDialog(
      context,
      initial: state.defaultReps,
    );
    if (reps != null) cubit.setDefaultReps(reps);
  }

  Future<void> _editRange(BuildContext context) async {
    final cubit = context.read<SettingsCubit>();
    final range = await editDefaultRepRangeDialog(
      context,
      min: state.defaultRepRangeMin,
      max: state.defaultRepRangeMax,
    );
    if (range case (final min, final max)) {
      cubit.setDefaultRepRange(min: min, max: max);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
          child: Text(
            'Workout defaults',
            style: context.theme.typography.body.md.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Padding(
          padding: _kSettingsRowPadding,
          child: FCard(
            child: FItem.raw(
              child: Row(
                children: [
                  Icon(
                    FLucideIcons.slidersHorizontal,
                    color: context.theme.colors.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Default rep mode',
                          style: context.theme.typography.body.md,
                        ),
                        Text(
                          'Used for new exercises without a previous set',
                          style: context.theme.typography.body.xs.copyWith(
                            color: context.theme.colors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _MenuSelect<RepMode>(
                    options: const {
                      'Rep range': RepMode.range,
                      'Fixed reps': RepMode.fixed,
                    },
                    value: state.defaultRepMode,
                    onChanged: context.read<SettingsCubit>().setDefaultRepMode,
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: _kSettingsRowPadding,
          child: FCard(
            child: FItem(
              prefix: Icon(
                FLucideIcons.hash,
                color: context.theme.colors.primary,
              ),
              title: const Text('Default reps'),
              subtitle: Text(
                'Pre-filled when adding a fixed set',
                style: context.theme.typography.body.xs.copyWith(
                  color: context.theme.colors.mutedForeground,
                ),
              ),
              details: Text('${state.defaultReps}'),
              suffix: const Icon(FLucideIcons.chevronRight, size: 16),
              onPress: () => _editReps(context),
            ),
          ),
        ),
        Padding(
          padding: _kSettingsRowPadding,
          child: FCard(
            child: FItem(
              prefix: Icon(
                FLucideIcons.moveHorizontal,
                color: context.theme.colors.primary,
              ),
              title: const Text('Default rep range'),
              subtitle: Text(
                'Pre-filled when adding a range set',
                style: context.theme.typography.body.xs.copyWith(
                  color: context.theme.colors.mutedForeground,
                ),
              ),
              details: Text(
                '${state.defaultRepRangeMin}-${state.defaultRepRangeMax}',
              ),
              suffix: const Icon(FLucideIcons.chevronRight, size: 16),
              onPress: () => _editRange(context),
            ),
          ),
        ),
      ],
    );
  }
}
