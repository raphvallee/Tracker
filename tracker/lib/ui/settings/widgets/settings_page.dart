import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/rep_mode.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/utils/form_validators.dart';

import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/core/ui/keyboard_inset.dart';
import 'package:tracker/ui/core/ui/max_width.dart';
import 'package:tracker/ui/settings/widgets/gyms_page.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';

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
                // Bottom padding tracks the keyboard so the workout-defaults
                // fields scroll above it (shell no longer resizes for the
                // keyboard).
                padding: EdgeInsets.fromLTRB(
                  0,
                  12,
                  0,
                  12 + keyboardInsetOf(context),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: FCard(
        child: FItem.raw(
          child: Row(
            children: [
              Icon(icon, color: context.theme.colors.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.theme.typography.body.md),
                    Text(
                      subtitle,
                      style: context.theme.typography.body.xs.copyWith(
                        color: context.theme.colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 120,
                child: FSelect<WeightUnit>(
                  items: {
                    for (final unit in WeightUnit.values) unit.symbol: unit,
                  },
                  control: FSelectControl<WeightUnit>.lifted(
                    value: value,
                    onChange: (unit) {
                      if (unit != null) {
                        onChanged(unit);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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

/// "Workout defaults" section: the rep mode, rep count and rep range
/// pre-filled when adding sets to exercises in the split editor. Numeric
/// fields commit on every valid change; invalid input shows an inline error
/// and keeps the last persisted value.
class _WorkoutDefaultsSection extends StatefulWidget {
  const _WorkoutDefaultsSection({required this.state});

  /// Current settings, lifted from the enclosing BlocBuilder so the
  /// rep-mode dropdown reflects the persisted value.
  final SettingsState state;

  @override
  State<_WorkoutDefaultsSection> createState() =>
      _WorkoutDefaultsSectionState();
}

class _WorkoutDefaultsSectionState extends State<_WorkoutDefaultsSection> {
  late final TextEditingController _reps;
  late final TextEditingController _rangeMin;
  late final TextEditingController _rangeMax;
  String? _repsError;
  String? _minError;
  String? _maxError;

  @override
  void initState() {
    super.initState();
    // context.read is allowed in initState; the provider sits above the page.
    final state = SettingsCubit.maybeOf(context)?.state ?? widget.state;
    _reps = TextEditingController(text: '${state.defaultReps}');
    _rangeMin = TextEditingController(text: '${state.defaultRepRangeMin}');
    _rangeMax = TextEditingController(text: '${state.defaultRepRangeMax}');
  }

  @override
  void dispose() {
    _reps.dispose();
    _rangeMin.dispose();
    _rangeMax.dispose();
    super.dispose();
  }

  void _commitReps(TextEditingValue value) {
    final error = requiredInt(value.text);
    setState(() => _repsError = error);
    if (error == null) {
      context.read<SettingsCubit>().setDefaultReps(
        int.parse(value.text.trim()),
      );
    }
  }

  void _commitRange() {
    final minError = requiredInt(_rangeMin.text);
    final maxError = requiredInt(_rangeMax.text);
    var crossedError = maxError;
    final min = int.tryParse(_rangeMin.text.trim());
    final max = int.tryParse(_rangeMax.text.trim());
    if (minError == null && maxError == null && min! > max!) {
      crossedError = 'Must be at least the min';
    }
    setState(() {
      _minError = minError;
      _maxError = crossedError;
    });
    if (minError == null && crossedError == null) {
      context.read<SettingsCubit>().setDefaultRepRange(min: min!, max: max!);
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                  SizedBox(
                    width: 120,
                    child: FSelect<RepMode>(
                      items: const {
                        'Rep range': RepMode.range,
                        'Fixed reps': RepMode.fixed,
                      },
                      control: FSelectControl<RepMode>.lifted(
                        value: widget.state.defaultRepMode,
                        onChange: (mode) {
                          if (mode != null) {
                            context.read<SettingsCubit>().setDefaultRepMode(
                              mode,
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: FCard(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        FLucideIcons.hash,
                        color: context.theme.colors.primary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Default reps',
                              style: context.theme.typography.body.md,
                            ),
                            Text(
                              'Pre-filled when adding a fixed set',
                              style: context.theme.typography.body.xs.copyWith(
                                color: context.theme.colors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 120,
                    child: FTextField(
                      control: FTextFieldControl.managed(
                        controller: _reps,
                        onChange: _commitReps,
                      ),
                      keyboardType: TextInputType.number,
                      label: const Text('Reps'),
                      error: _repsError == null ? null : Text(_repsError!),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: FCard(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        FLucideIcons.moveHorizontal,
                        color: context.theme.colors.primary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Default rep range',
                              style: context.theme.typography.body.md,
                            ),
                            Text(
                              'Pre-filled when adding a range set',
                              style: context.theme.typography.body.xs.copyWith(
                                color: context.theme.colors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FTextField(
                          control: FTextFieldControl.managed(
                            controller: _rangeMin,
                            onChange: (_) => _commitRange(),
                          ),
                          keyboardType: TextInputType.number,
                          label: const Text('Min'),
                          error: _minError == null ? null : Text(_minError!),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FTextField(
                          control: FTextFieldControl.managed(
                            controller: _rangeMax,
                            onChange: (_) => _commitRange(),
                          ),
                          keyboardType: TextInputType.number,
                          label: const Text('Max'),
                          error: _maxError == null ? null : Text(_maxError!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
