import 'dart:collection';

import 'package:tracker/domain/models/workout_session.dart';

/// Counts source reads without relying on host timing or production counters.
class CountingSessions extends ListBase<WorkoutSession> {
  CountingSessions(this._values);

  final List<WorkoutSession> _values;
  int reads = 0;

  @override
  int get length => _values.length;

  @override
  WorkoutSession operator [](int index) {
    reads++;
    return _values[index];
  }

  @override
  set length(int value) => throw UnsupportedError('Immutable snapshot');

  @override
  void operator []=(int index, WorkoutSession value) =>
      throw UnsupportedError('Immutable snapshot');
}
