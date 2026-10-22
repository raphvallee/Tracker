import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/models/weight_unit.dart';

void main() {
  test('weight entry range is -1000 to 10000', () {
    expect(minimumWeight, -1000);
    expect(maximumWeight, 10000);
  });

  test('the heavy-weight prompt threshold is per unit', () {
    expect(WeightUnit.kilograms.heavyWeightThreshold, 500);
    expect(WeightUnit.pounds.heavyWeightThreshold, 1000);
  });
}
