/// Most decimal places a weight or reps value keeps. Input is truncated, never
/// rounded, so the stored value is exactly the leading digits that were typed.
const int maxDecimalPlaces = 2;

final _unsignedPrefix = RegExp('^\\d*\\.?\\d{0,$maxDecimalPlaces}');
final _signedPrefix = RegExp('^-?\\d*\\.?\\d{0,$maxDecimalPlaces}');

String decimalPrefix(String text, {bool allowNegative = false}) {
  final pattern = allowNegative ? _signedPrefix : _unsignedPrefix;
  return pattern.firstMatch(text)?.group(0) ?? '';
}

double? parseDecimal(String text, {bool allowNegative = false}) {
  final prefix = decimalPrefix(
    text.trim().replaceAll(',', '.'),
    allowNegative: allowNegative,
  );
  final value = double.tryParse(prefix);
  return value == 0 ? 0.0 : value;
}
