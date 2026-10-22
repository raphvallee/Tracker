/// User-facing application preferences value type persisted independently of
/// workout data.
enum FreeStartPlacement { before, after, disabled }

enum WeightUnit { kilograms, pounds }

/// Range a typed weight may take, in the unit the user typed (inclusive). A
/// negative weight records an assisted machine, such as an assisted pull-up.
const double minimumWeight = -1000;
const double maximumWeight = 10000;

extension WeightUnitLimit on WeightUnit {
  /// Typed weight above which the user must confirm the load is really theirs.
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
