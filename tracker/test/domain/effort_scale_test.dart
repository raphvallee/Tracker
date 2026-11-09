import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/models/effort_scale.dart';

void main() {
  test('reps in reserve read as 10 minus RPE, both ways', () {
    expect(EffortScale.rpe.fromRpe(8), 8);
    expect(EffortScale.rpe.toRpe(8), 8);
    expect(EffortScale.rir.fromRpe(8), 2);
    expect(EffortScale.rir.toRpe(0), 10);
    expect(EffortScale.rir.toRpe(EffortScale.rir.fromRpe(6.5)), 6.5);
    expect([for (final s in EffortScale.values) s.label], ['RPE', 'RIR']);
  });
}
