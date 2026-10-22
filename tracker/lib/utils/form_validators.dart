import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/utils/decimal_input.dart';

String? requiredText(String? value, {String msg = 'Cannot be empty'}) {
  return value?.trim().isNotEmpty == true ? null : msg;
}

String? requiredDouble(
  String? value, {
  double minimum = 0,
  String msg = 'Must be greater than 0',
}) {
  final number = double.tryParse(value?.trim() ?? '');
  return number != null && number > minimum ? null : msg;
}

/// Validates a whole-number field that must be at least [minimum].
String? requiredInt(
  String? value, {
  int minimum = 1,
  String msg = 'Must be at least 1',
}) {
  final number = int.tryParse(value?.trim() ?? '');
  return number != null && number >= minimum ? null : msg;
}

/// Validates a typed weight: a decimal from [minimumWeight] to [maximumWeight]
/// (inclusive). Zero is a valid bodyweight entry.
String? requiredWeight(
  String? value, {
  String msg = 'Must be between -1000 and 10000',
}) {
  final number = parseDecimal(value ?? '', allowNegative: true);
  return number != null && number >= minimumWeight && number <= maximumWeight
      ? null
      : msg;
}

/// Validates a typed reps count: a decimal above zero. Fractions below one are
/// accepted here and rejected by the form, which asks for at least one rep.
String? requiredReps(String? value, {String msg = 'Must be greater than 0'}) {
  final number = parseDecimal(value ?? '');
  return number != null && number > 0 ? null : msg;
}
