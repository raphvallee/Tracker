import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/utils/decimal_input.dart';

void main() {
  group('parseDecimal', () {
    test('keeps up to two decimal places', () {
      expect(parseDecimal('3.5'), 3.5);
      expect(parseDecimal('3.25'), 3.25);
      expect(parseDecimal('82.25'), 82.25);
    });

    test('truncates beyond two places and never rounds', () {
      expect(parseDecimal('3.555'), 3.55);
      expect(parseDecimal('12.345'), 12.34);
      expect(parseDecimal('0.999'), 0.99);
    });

    test('reads a leading decimal point and a trailing one', () {
      expect(parseDecimal('.5'), 0.5);
      expect(parseDecimal('5.'), 5);
    });

    test('reads a typed comma as a decimal point and trims spaces', () {
      expect(parseDecimal('3,25'), 3.25);
      expect(parseDecimal('  7  '), 7);
    });

    test('drops everything after the longest valid prefix', () {
      expect(parseDecimal('3.5.5'), 3.5);
      expect(parseDecimal('1,2,3'), 1.2);
    });

    test('returns null when no number can be read', () {
      expect(parseDecimal(''), isNull);
      expect(parseDecimal('.'), isNull);
      expect(parseDecimal('-'), isNull);
      expect(parseDecimal('abc'), isNull);
    });

    test('rejects a minus sign unless negatives are allowed', () {
      expect(parseDecimal('-5'), isNull);
      expect(parseDecimal('-5', allowNegative: true), -5);
      expect(parseDecimal('-.5', allowNegative: true), -0.5);
      expect(parseDecimal('-12.345', allowNegative: true), -12.34);
    });

    test('reads a negative zero as plain zero', () {
      final zero = parseDecimal('-0', allowNegative: true);
      expect(zero, 0);
      expect(zero!.isNegative, isFalse);
    });
  });

  group('decimalPrefix', () {
    test('keeps the longest leading decimal', () {
      expect(decimalPrefix('3.555'), '3.55');
      expect(decimalPrefix('abc'), '');
      expect(decimalPrefix('-5', allowNegative: true), '-5');
      expect(decimalPrefix('5-', allowNegative: true), '5');
    });
  });
}
