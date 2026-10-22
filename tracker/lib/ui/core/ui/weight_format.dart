import 'package:flutter/widgets.dart';
import 'package:tracker/domain/services/analytics.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/utils/decimal_input.dart';

WeightUnit weightUnitOf(BuildContext context) {
  return SettingsCubit.maybeOf(context)?.state.unit ?? WeightUnit.kilograms;
}

double displayWeightOf(BuildContext context, double kilograms) =>
    weightUnitOf(context).fromKilograms(kilograms);

double kilogramsFromDisplay(BuildContext context, double displayed) =>
    weightUnitOf(context).toKilograms(displayed);

String formatWeight(BuildContext context, double kilograms) {
  final value = displayWeightOf(context, kilograms);
  return '${formatDecimal(value)} ${weightUnitOf(context).symbol}';
}

/// Formats performed reps for display: whole reps without a decimal point
/// (`5`), fractional reps with up to two (`3.5`, `3.25`).
String formatReps(double reps) => formatDecimal(reps);

/// Formats a number with at most [maxDecimalPlaces] places and no trailing
/// zeros: `80` → "80", `82.5` → "82.5", `3.25` → "3.25".
String formatDecimal(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value
      .toStringAsFixed(maxDecimalPlaces)
      .replaceFirst(RegExp(r'\.?0+$'), '');
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
