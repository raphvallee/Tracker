/// Most decimal places a weight or reps value keeps. Input is truncated, never
/// rounded, so the stored value is exactly the leading digits that were typed.
const int maxDecimalPlaces = 2;

final _unsignedPrefix = RegExp('^\\d*\\.?\\d{0,$maxDecimalPlaces}');
final _signedPrefix = RegExp('^-?\\d*\\.?\\d{0,$maxDecimalPlaces}');

/// The longest leading part of [text] that is a decimal with at most
/// [maxDecimalPlaces] places. [allowNegative] admits a leading minus sign.
String decimalPrefix(String text, {bool allowNegative = false}) {
  final pattern = allowNegative ? _signedPrefix : _unsignedPrefix;
  return pattern.firstMatch(text)?.group(0) ?? '';
}

/// Parses [text] as a decimal with at most [maxDecimalPlaces] places. A ','
/// reads as '.', and anything after the longest valid prefix is dropped
/// ("3.555" reads as 3.55, "3.5.5" as 3.5). Returns null when no number can be
/// read. A negative zero reads as plain zero.
double? parseDecimal(String text, {bool allowNegative = false}) {
  final prefix = decimalPrefix(
    text.trim().replaceAll(',', '.'),
    allowNegative: allowNegative,
  );
  final value = double.tryParse(prefix);
  return value == 0 ? 0.0 : value;
}
