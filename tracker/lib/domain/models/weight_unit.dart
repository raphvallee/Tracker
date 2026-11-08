enum FreeStartPlacement { before, after, disabled }

enum WeightUnit { kilograms, pounds }

const double minimumWeight = -1000;
const double maximumWeight = 10000;

extension WeightUnitLimit on WeightUnit {
  double get heavyWeightThreshold => this == WeightUnit.kilograms ? 500 : 1000;
}

extension WeightUnitLabel on WeightUnit {
  String get label =>
      this == WeightUnit.kilograms ? 'Kilograms (kg)' : 'Pounds (lb)';

  String get symbol => this == WeightUnit.kilograms ? 'kg' : 'lb';

  double fromKilograms(double value) =>
      this == WeightUnit.kilograms ? value : value * 2.2046226218;

  double toKilograms(double value) =>
      this == WeightUnit.kilograms ? value : value / 2.2046226218;
}
