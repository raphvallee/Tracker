import 'package:flutter/widgets.dart';
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

/// A total lifted, rounded and grouped by thousands: "5,540 kg".
String formatVolume(BuildContext context, double kilograms) =>
    '${groupedNumber(displayWeightOf(context, kilograms))} '
    '${weightUnitOf(context).symbol}';

/// [value] rounded and grouped by thousands: "5,540".
String groupedNumber(double value) {
  final digits = value.round().abs().toString();
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
    grouped.write(digits[i]);
  }
  return grouped.toString();
}

String formatDecimal(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value
      .toStringAsFixed(maxDecimalPlaces)
      .replaceFirst(RegExp(r'\.?0+$'), '');
}

String plural(String noun, int n) => n == 1 ? '1 $noun' : '$n ${noun}s';
