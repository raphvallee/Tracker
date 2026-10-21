import 'package:flutter/widgets.dart';
import 'package:tracker/domain/services/analytics.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';

WeightUnit weightUnitOf(BuildContext context) {
  return SettingsCubit.maybeOf(context)?.state.unit ?? WeightUnit.kilograms;
}

double displayWeightOf(BuildContext context, double kilograms) =>
    weightUnitOf(context).fromKilograms(kilograms);

double kilogramsFromDisplay(BuildContext context, double displayed) =>
    weightUnitOf(context).toKilograms(displayed);

String formatWeight(BuildContext context, double kilograms) {
  final value = displayWeightOf(context, kilograms);
  final formatted = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$formatted ${weightUnitOf(context).symbol}';
}

/// Formats performed reps for display: whole reps without a decimal point
/// (`5`), fractional reps with exactly one (`3.5`).
String formatReps(double reps) {
  return reps == reps.roundToDouble()
      ? reps.toStringAsFixed(0)
      : reps.toStringAsFixed(1);
}

List<ProgressionPoint> displayProgressionPoints(
  BuildContext context,
  List<ProgressionPoint> points,
) {
  final unit = weightUnitOf(context);
  return [
    for (final point in points)
      ProgressionPoint(
        date: point.date,
        value: unit.fromKilograms(point.value),
      ),
  ];
}

/// Counted noun for UI labels: `plural('set', 3)` → "3 sets", `plural('set', 1)`
/// → "1 set" (plain concatenation would render "1 sets").
String plural(String noun, int n) => n == 1 ? '1 $noun' : '$n ${noun}s';
