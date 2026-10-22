import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/ui/core/ui/decimal_input_formatter.dart';

TextEditingValue _edit(
  DecimalInputFormatter formatter,
  String oldText,
  String newText,
) {
  return formatter.formatEditUpdate(
    TextEditingValue(
      text: oldText,
      selection: TextSelection.collapsed(offset: oldText.length),
    ),
    TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    ),
  );
}

void main() {
  final reps = DecimalInputFormatter();
  final weight = DecimalInputFormatter(allowNegative: true);

  group('DecimalInputFormatter (reps)', () {
    test('allows up to two decimal places', () {
      expect(_edit(reps, '3.5', '3.55').text, '3.55');
      expect(_edit(reps, '3', '3.2').text, '3.2');
    });

    test('blocks a third decimal digit while typing', () {
      expect(_edit(reps, '3.55', '3.555').text, '3.55');
    });

    test('truncates a pasted value to its longest valid prefix', () {
      expect(_edit(reps, '', '12.345').text, '12.34');
      expect(_edit(reps, '', '3.5x').text, '3.5');
    });

    test('ignores a second decimal separator', () {
      expect(_edit(reps, '3.5', '3.5.5').text, '3.5');
    });

    test('reads a typed comma as a decimal point', () {
      expect(_edit(reps, '3', '3,5').text, '3.5');
    });

    test('drops letters and minus signs', () {
      expect(_edit(reps, '', 'abc').text, '');
      expect(_edit(reps, '', '-5').text, '');
    });

    test('keeps the old value when the edit cannot be salvaged', () {
      expect(_edit(reps, '3.5', '3.5x').text, '3.5');
    });

    test('places the caret at the end after truncating', () {
      final result = _edit(reps, '', '12.345');
      expect(result.selection.baseOffset, result.text.length);
    });

    test('accepts a leading decimal point', () {
      expect(_edit(reps, '', '.5').text, '.5');
    });
  });

  group('DecimalInputFormatter (weight)', () {
    test('accepts a leading minus sign, including a lone one', () {
      expect(_edit(weight, '', '-').text, '-');
      expect(_edit(weight, '', '-20').text, '-20');
      expect(_edit(weight, '', '-.5').text, '-.5');
    });

    test('drops a minus sign that is not leading', () {
      expect(_edit(weight, '5', '5-').text, '5');
      expect(_edit(weight, '', '--5').text, '-');
    });

    test('keeps two decimal places like reps', () {
      expect(_edit(weight, '82.2', '82.25').text, '82.25');
      expect(_edit(weight, '82.25', '82.255').text, '82.25');
      expect(_edit(weight, '', '82.255').text, '82.25');
    });
  });
}
