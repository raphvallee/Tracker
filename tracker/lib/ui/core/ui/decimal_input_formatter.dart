import 'package:flutter/services.dart';
import 'package:tracker/utils/decimal_input.dart';

/// Keeps a weight or reps field to at most two decimal places: "82.255" can
/// never be typed, a second decimal separator is ignored, and a pasted value is
/// truncated to its longest valid prefix ("82.255" pastes as "82.25"). A typed
/// ',' is read as '.'. [allowNegative] admits a leading minus (weight only,
/// where a negative value means an assisted machine).
class DecimalInputFormatter extends TextInputFormatter {
  DecimalInputFormatter({this.allowNegative = false});

  final bool allowNegative;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // The length is unchanged by the ',' swap, so the selection stays valid.
    final text = newValue.text.replaceAll(',', '.');
    final prefix = decimalPrefix(text, allowNegative: allowNegative);
    if (prefix == text) {
      return text == newValue.text
          ? newValue
          : newValue.copyWith(text: text, composing: TextRange.empty);
    }
    if (prefix == oldValue.text) return oldValue;
    return TextEditingValue(
      text: prefix,
      selection: TextSelection.collapsed(offset: prefix.length),
      composing: TextRange.empty,
    );
  }
}
