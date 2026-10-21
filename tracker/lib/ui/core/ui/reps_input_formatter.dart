import 'package:flutter/services.dart';

/// Blocks input beyond one decimal place on the reps field: "3.55" can never
/// be typed, a second decimal separator is ignored, and a pasted value is
/// truncated to one decimal ("3.55" pastes as "3.5").
class RepsInputFormatter extends TextInputFormatter {
  static final _oneDecimal = RegExp(r'^\d*\.?\d?$');
  static final _validPrefix = RegExp(r'^\d*\.?\d?');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Accept a typed ',' as a decimal separator too; the length is unchanged,
    // so the existing selection stays valid.
    final text = newValue.text.replaceAll(',', '.');
    if (_oneDecimal.hasMatch(text)) {
      return text == newValue.text
          ? newValue
          : newValue.copyWith(text: text, composing: TextRange.empty);
    }
    // Pasted (or otherwise hand-set) values: keep the longest valid prefix.
    final prefix = _validPrefix.firstMatch(text)?.group(0) ?? '';
    if (prefix == oldValue.text) return oldValue;
    return TextEditingValue(
      text: prefix,
      selection: TextSelection.collapsed(offset: prefix.length),
      composing: TextRange.empty,
    );
  }
}
