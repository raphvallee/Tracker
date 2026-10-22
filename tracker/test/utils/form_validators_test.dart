import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/utils/form_validators.dart';

void main() {
  test('requiredText accepts content and rejects blank values', () {
    expect(requiredText(' value '), isNull);
    expect(requiredText(null), 'Cannot be empty');
    expect(requiredText('  '), 'Cannot be empty');
  });

  test('requiredDouble requires a positive number', () {
    expect(requiredDouble('1.5'), isNull);
    expect(requiredDouble(null), 'Must be greater than 0');
    expect(requiredDouble('0'), 'Must be greater than 0');
    expect(requiredDouble('-1'), 'Must be greater than 0');
    expect(requiredDouble('abc'), 'Must be greater than 0');
  });

  test('requiredInt requires a whole number of at least the minimum', () {
    expect(requiredInt('10'), isNull);
    expect(requiredInt('1'), isNull);
    expect(requiredInt('0'), 'Must be at least 1');
    expect(requiredInt('-3'), 'Must be at least 1');
    expect(requiredInt('1.5'), 'Must be at least 1');
    expect(requiredInt(null), 'Must be at least 1');
    expect(requiredInt('abc'), 'Must be at least 1');
    expect(requiredInt('0', minimum: 0), isNull);
  });

  group('requiredWeight', () {
    const message = 'Must be between -1000 and 10000';

    test('accepts the inclusive range, zero and negatives', () {
      expect(requiredWeight('-1000'), isNull);
      expect(requiredWeight('10000'), isNull);
      expect(requiredWeight('0'), isNull);
      expect(requiredWeight('-0.5'), isNull);
      expect(requiredWeight(' 82.25 '), isNull);
    });

    test('rejects values just outside the range', () {
      expect(requiredWeight('-1000.01'), message);
      expect(requiredWeight('10000.01'), message);
      expect(requiredWeight('-1001'), message);
      expect(requiredWeight('10001'), message);
    });

    test('rejects empty, partial and non-numeric input', () {
      expect(requiredWeight(null), message);
      expect(requiredWeight(''), message);
      expect(requiredWeight('-'), message);
      expect(requiredWeight('.'), message);
      expect(requiredWeight('abc'), message);
      expect(requiredWeight('NaN'), message);
      expect(requiredWeight('Infinity'), message);
    });
  });

  group('requiredReps', () {
    test('accepts any decimal above zero, including fractions below one', () {
      expect(requiredReps('5'), isNull);
      expect(requiredReps('0.25'), isNull);
      expect(requiredReps('.5'), isNull);
    });

    test('rejects zero, negatives and non-numeric input', () {
      expect(requiredReps('0'), 'Must be greater than 0');
      expect(requiredReps('-1'), 'Must be greater than 0');
      expect(requiredReps(null), 'Must be greater than 0');
      expect(requiredReps('abc'), 'Must be greater than 0');
    });
  });
}
