import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';

void main() {
  group('formatDecimal', () {
    test('drops the decimal point for whole numbers', () {
      expect(formatDecimal(80), '80');
      expect(formatDecimal(1000), '1000');
    });

    test('keeps up to two decimal places without trailing zeros', () {
      expect(formatDecimal(82.5), '82.5');
      expect(formatDecimal(82.25), '82.25');
      expect(formatDecimal(3.55), '3.55');
      expect(formatDecimal(0.5), '0.5');
    });

    test('rounds away a sub-hundredth remainder that is not whole', () {
      expect(formatDecimal(100.001), '100');
      expect(formatDecimal(0.001), '0');
    });

    test('formats converted pound values to two places', () {
      expect(formatDecimal(176.3698), '176.37');
    });

    test('keeps the sign', () {
      expect(formatDecimal(-20), '-20');
      expect(formatDecimal(-0.5), '-0.5');
    });
  });

  group('formatReps', () {
    test('shows whole reps without a decimal point', () {
      expect(formatReps(5), '5');
    });

    test('shows fractional reps with up to two places', () {
      expect(formatReps(3.5), '3.5');
      expect(formatReps(3.25), '3.25');
    });
  });
}
