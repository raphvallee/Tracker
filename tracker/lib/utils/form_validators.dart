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
