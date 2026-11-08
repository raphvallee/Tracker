import 'package:flutter/services.dart';
import 'package:tracker/utils/decimal_input.dart';

class DecimalInputFormatter extends TextInputFormatter {
  DecimalInputFormatter({this.allowNegative = false});

  final bool allowNegative;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
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
