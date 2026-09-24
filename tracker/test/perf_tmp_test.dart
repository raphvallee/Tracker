import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/models/graph_config.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/services/analytics.dart';

WorkoutSession _session(int id, int gymId, DateTime start, int sets) =>
    WorkoutSession(
      title: 's$id',
      startTime: start,
      endTime: start.add(const Duration(hours: 1)),
      gymId: gymId,
      sets: [
        for (var i = 0; i < sets; i++)
          WorkoutSet(
            exerciseId: i % 15,
            weight: 60 + (id % 20),
            reps: 8,
            type: SetType.working,
            order: i,
          ),
      ],
    );

void main() {
  test('perf probe: estimation + graphPoints scaling', () {
    final now = DateTime(2026, 9, 16);
    final sessions = [
      for (var i = 0; i < 2000; i++)
        _session(i, i.isEven ? 1 : 2, now.subtract(Duration(days: i ~/ 4)), 6),
    ];

    final w1 = Stopwatch()..start();
    final estimates = estimateGymExerciseMultipliers(sessions, 1, 2);
    w1.stop();

    final w2 = Stopwatch()..start();
    final scalar = estimateGymMultiplier(sessions, 1, 2);
    w2.stop();
    // ignore: avoid_print
    print(
      'PERF estimateGymExerciseMultipliers S=2000,T=6: ${w1.elapsedMicroseconds}us',
    );
    // ignore: avoid_print
    print(
      'PERF estimateGymMultiplier (duplicate scan): ${w2.elapsedMicroseconds}us, n=${estimates.length}, scalar=$scalar',
    );

    final config = GraphConfig(
      title: 'g',
      metric: GraphMetric.volume,
      exerciseId: null,
      timeframe: GraphTimeframe.last90Days,
    );
    const multipliers = {2: 1.1};
    final w3 = Stopwatch()..start();
    for (var i = 0; i < 8; i++) {
      graphPoints(config: config, sessions: sessions, multipliers: multipliers);
    }
    w3.stop();
    // ignore: avoid_print
    print(
      'PERF graphPoints x8 cards: ${w3.elapsedMilliseconds}ms total, ${(w3.elapsedMicroseconds / 8 / 1000).toStringAsFixed(1)}ms/card',
    );
  });
}
