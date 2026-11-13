/// What opens when a weight or reps value is tapped during a workout.
enum NumberEntry {
  /// The keypad with a - and + rocker in its key column.
  keypadSteppers,

  /// The keypad with a ruler on top of its keys.
  keypadRuler,
  phoneKeyboard;

  /// The in-app keypad opens with its steppers, so a value shows its number
  /// alone.
  bool get usesKeypad => this != phoneKeyboard;
}
