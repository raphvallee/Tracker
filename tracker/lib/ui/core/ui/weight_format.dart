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

String formatReps(double reps) => formatDecimal(reps);

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

String plural(String noun, int n) => n == 1 ? '1 $noun' : '$n ${noun}s';
