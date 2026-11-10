import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/ui/workout/widgets/set_comparison.dart';

void main() {
  SetComparison? compare(
    double weight,
    double reps, {
    double lastWeight = 27.5,
    double lastReps = 9,
  }) => compareWithLast(
    weight: weight,
    reps: reps,
    lastWeight: lastWeight,
    lastReps: lastReps,
    unit: 'kg',
  );

  test('the same set as last time says nothing', () {
    expect(compare(27.5, 9), isNull);
    // Float dust from a unit conversion is not a difference.
    expect(compare(27.5004, 9), isNull);
  });

  test('one value up or down names it alone', () {
    expect(compare(30, 9)!.text, '2.5 kg more than last time');
    expect(compare(25, 9)!.text, '2.5 kg less than last time');
    expect(compare(27.5, 10)!.text, '1 rep more than last time');
    expect(compare(27.5, 7)!.text, '2 reps fewer than last time');
  });

  test('both values the same way share one verdict', () {
    expect(compare(30, 10)!.text, '2.5 kg and 1 rep more than last time');
    expect(compare(25, 7)!.text, '2.5 kg and 2 reps less than last time');
  });

  test('values going opposite ways are both spelled out', () {
    expect(compare(30, 7)!.text, '2.5 kg more, 2 reps fewer than last time');
    expect(compare(25, 11)!.text, '2.5 kg less, 2 reps more than last time');
  });

  test('ahead means nothing went down', () {
    expect(compare(30, 9)!.isAhead, isTrue);
    expect(compare(30, 10)!.isAhead, isTrue);
    expect(compare(30, 7)!.isAhead, isFalse);
    expect(compare(25, 9)!.isAhead, isFalse);
  });
}
