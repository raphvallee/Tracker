// Unit tests for the analytics layer (lib/analytics/analytics.dart) — pure
// functions/classes with no Isar and no widgets. Chart widgets that consume
// this layer are integration (widget) tests: test/integration/analytics_test.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/models/graph_config.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/services/analytics.dart';

WorkoutSet _set(int exerciseId, double weight, double reps, SetType type) =>
    WorkoutSet(exerciseId: exerciseId, weight: weight, reps: reps, type: type);

WorkoutSession _session(DateTime start, int gymId, List<WorkoutSet> sets) =>
    WorkoutSession(startTime: start, gymId: gymId, sets: sets);

void main() {
  group('1RM estimate (Epley)', () {
    test('multiplies by (1 + reps/30) for reps > 1', () {
      expect(
        epley1rm(weight: 100, reps: 5),
        closeTo(100 * (1 + 5 / 30), 0.001),
      );
    });

    test('returns weight unchanged for 1 or 0 reps', () {
      expect(epley1rm(weight: 100, reps: 1), 100);
      expect(epley1rm(weight: 100, reps: 0), 100);
    });
  });

  group('normalizedWeight (§2.3)', () {
    const multipliers = {1: 1.0, 2: 0.9};

    test('scales by the session gym\'s multiplier', () {
      expect(normalizedWeight(110, multipliers, 2), closeTo(99, 0.001));
      expect(normalizedWeight(110, multipliers, 1), 110);
    });

    test('defaults to 1.0 for unknown/null gym', () {
      expect(normalizedWeight(110, multipliers, null), 110);
      expect(normalizedWeight(110, multipliers, 99), 110);
    });
  });

  group('per-exercise series excludes warmups + normalizes', () {
    test('unifies the same movement across two gyms (checkpoint)', () {
      // Same exercise logged at gym A (mult 1.0) and gym B (mult 0.9).
      final sessions = [
        _session(DateTime(2026, 1, 1), 1, [
          _set(7, 100, 5, SetType.working),
          _set(7, 60, 8, SetType.warmup), // excluded
        ]),
        _session(DateTime(2026, 1, 2), 2, [
          _set(7, 110, 5, SetType.working), // normalized → 99
          _set(7, 70, 8, SetType.warmup), // excluded
        ]),
      ];
      const multipliers = {1: 1.0, 2: 0.9};

      final series = exerciseBest1rm(sessions, multipliers, 7);
      expect(series, hasLength(2));
      expect(series[0].date, DateTime(2026, 1, 1));
      expect(series[0].value, closeTo(epley1rm(weight: 100, reps: 5), 0.001));
      // Raw 110 × 0.9 = 99, then Epley.
      expect(series[1].value, closeTo(epley1rm(weight: 99, reps: 5), 0.001));
    });

    test('skips sessions with only warmup sets for that exercise', () {
      final sessions = [
        _session(DateTime(2026, 1, 1), 1, [_set(7, 60, 8, SetType.warmup)]),
      ];
      expect(exerciseBest1rm(sessions, const {}, 7), isEmpty);
    });

    test('exercisePeakWeight uses normalized working weight', () {
      final sessions = [
        _session(DateTime(2026, 1, 1), 2, [_set(7, 110, 5, SetType.working)]),
      ];
      const multipliers = {2: 0.9};
      final peak = exercisePeakWeight(sessions, multipliers, 7);
      expect(peak.single.value, closeTo(99, 0.001));
    });
  });

  group('volume trend (§2.1, §2.4)', () {
    test('excludes warmup sets and normalizes weight', () {
      final sessions = [
        _session(DateTime(2026, 1, 1), 2, [
          _set(1, 100, 5, SetType.working), // 100×0.9×5 = 450
          _set(1, 60, 8, SetType.warmup), // excluded
        ]),
      ];
      const multipliers = {2: 0.9};
      final trend = volumeTrend(sessions, multipliers);
      expect(trend.single.value, closeTo(450, 0.001));
    });
  });

  group('exerciseSummary', () {
    test('aggregates working sets across sessions', () {
      final sessions = [
        _session(DateTime(2026, 1, 1), 1, [
          _set(7, 100, 5, SetType.working),
          _set(7, 60, 8, SetType.warmup),
        ]),
        _session(DateTime(2026, 1, 2), 1, [_set(7, 90, 5, SetType.working)]),
      ];
      final s = exerciseSummary(sessions, const {1: 1.0}, 7);
      expect(s.sessionCount, 2);
      expect(s.best1rm, closeTo(epley1rm(weight: 100, reps: 5), 0.001));
      expect(s.peakVolume, closeTo(500, 0.001));
    });
  });

  group('AnalyticsService snapshots', () {
    test('memoizes equivalent inputs and keeps snapshot immutable', () {
      final sessions = [
        _session(DateTime(2026, 1, 1), 1, [_set(7, 100, 5, SetType.working)]),
      ];
      final service = AnalyticsService();
      final first = service.snapshot(
        sessions: sessions,
        multipliers: const {1: 1.0},
        exerciseId: 7,
        revision: 3,
      );
      final second = service.snapshot(
        sessions: sessions,
        multipliers: const {1: 1.0},
        exerciseId: 7,
        revision: 3,
      );
      expect(identical(first, second), isTrue);
      expect(() => first.best1rm.clear(), throwsA(anything));
    });

    test('snapshot matches standalone metrics for selected exercise', () {
      final sessions = [
        _session(DateTime(2026, 1, 1), 1, [
          _set(7, 100, 5, SetType.working),
          _set(8, 200, 2, SetType.working),
          _set(7, 60, 8, SetType.warmup),
        ]),
        _session(DateTime(2026, 1, 2), 2, [_set(7, 110, 5, SetType.working)]),
      ];
      const multipliers = {1: 1.0, 2: 0.9};
      final exerciseMultipliers = <int, Map<int, double>>{
        2: {7: 0.8},
      };
      final service = AnalyticsService();
      final snapshot = service.snapshot(
        sessions: sessions,
        multipliers: multipliers,
        exerciseMultipliers: exerciseMultipliers,
        exerciseId: 7,
      );

      final best = exerciseBest1rm(
        sessions,
        multipliers,
        7,
        exerciseMultipliers,
      );
      final peak = exercisePeakWeight(
        sessions,
        multipliers,
        7,
        exerciseMultipliers,
      );
      final allVolume = volumeTrend(
        sessions,
        multipliers,
        null,
        exerciseMultipliers,
      );
      final summary = exerciseSummary(
        sessions,
        multipliers,
        7,
        exerciseMultipliers,
      );

      expect(
        snapshot.best1rm.map((point) => point.value),
        best.map((point) => point.value),
      );
      expect(
        snapshot.peakWeight.map((point) => point.value),
        peak.map((point) => point.value),
      );
      expect(
        snapshot.volume.map((point) => point.value),
        allVolume.map((point) => point.value),
      );
      expect(snapshot.summary.best1rm, summary.best1rm);
      expect(snapshot.summary.peakVolume, summary.peakVolume);
      expect(snapshot.summary.sessionCount, summary.sessionCount);
    });

    test('recomputes when revision, filter, or multiplier changes', () {
      final sessions = [
        _session(DateTime(2026, 1, 1), 1, [_set(7, 100, 5, SetType.working)]),
      ];
      final service = AnalyticsService();
      final first = service.compute(
        sessions: sessions,
        multipliers: const {1: 1.0},
        revision: 1,
      );
      expect(
        identical(
          first,
          service.compute(
            sessions: sessions,
            multipliers: const {1: 1.0},
            revision: 2,
          ),
        ),
        isFalse,
      );
      expect(
        identical(
          first,
          service.compute(
            sessions: sessions,
            multipliers: const {1: 0.9},
            revision: 1,
          ),
        ),
        isFalse,
      );
      expect(
        identical(
          first,
          service.compute(
            sessions: sessions,
            multipliers: const {1: 1.0},
            exerciseId: 7,
            revision: 1,
          ),
        ),
        isFalse,
      );
    });
  });

  group('user graph series', () {
    test('filters timeframe and exercise volume', () {
      final sessions = [
        _session(DateTime(2025, 12, 1), 1, [_set(7, 10, 5, SetType.working)]),
        _session(DateTime(2026, 4, 1), 1, [_set(8, 20, 3, SetType.working)]),
      ];
      final points = graphSeries(
        sessions: sessions,
        multipliers: const {1: 1.0},
        metric: GraphMetric.volume,
        exerciseId: 7,
        timeframe: GraphTimeframe.last90Days,
      );
      expect(points, hasLength(0));
      expect(graphMetricLabel(GraphMetric.best1rm), 'Best 1RM');
      expect(graphTimeframeLabel(GraphTimeframe.last30Days), 'Last 30 days');
    });

    test('all-time graph returns selected metric', () {
      final points = graphSeries(
        sessions: [
          _session(DateTime(2026, 1, 1), 1, [_set(7, 10, 5, SetType.working)]),
        ],
        multipliers: const {1: 1.0},
        metric: GraphMetric.volume,
      );
      expect(points.single.value, 50);
    });
  });

  group('estimateGymMultiplier (§2.3)', () {
    test('median of mean-ratio across shared exercises', () {
      final sessions = [
        _session(DateTime(2026, 1, 1), 1, [
          _set(1, 100, 5, SetType.working),
          _set(1, 100, 5, SetType.working),
          _set(2, 50, 8, SetType.working),
        ]),
        _session(DateTime(2026, 1, 2), 2, [
          _set(1, 110, 5, SetType.working),
          _set(1, 110, 5, SetType.working),
          _set(2, 60, 8, SetType.working),
        ]),
      ];
      // ex1 ratio 100/110 = 0.909; ex2 ratio 50/60 = 0.833; median = 0.909.
      final estimate = estimateGymMultiplier(sessions, 1, 2);
      expect(estimate, isNotNull);
      expect(estimate!, closeTo(0.9090909, 0.001));
    });

    test('returns null with no shared exercises', () {
      final sessions = [
        _session(DateTime(2026, 1, 1), 1, [_set(1, 100, 5, SetType.working)]),
        _session(DateTime(2026, 1, 2), 2, [_set(3, 40, 8, SetType.working)]),
      ];
      expect(estimateGymMultiplier(sessions, 1, 2), isNull);
    });

    test('supports per-exercise override before gym fallback', () {
      expect(
        normalizedWeight(
          100,
          const {2: 0.9},
          2,
          7,
          const {
            2: {7: 0.8},
          },
        ),
        closeTo(80, 0.001),
      );
    });

    test('recent observations dominate time-weighted estimate', () {
      final sessions = [
        _session(DateTime(2025, 1, 1), 1, [_set(1, 100, 5, SetType.working)]),
        _session(DateTime(2025, 1, 1), 2, [_set(1, 200, 5, SetType.working)]),
        _session(DateTime(2026, 1, 1), 1, [_set(1, 100, 5, SetType.working)]),
        _session(DateTime(2026, 1, 1), 2, [_set(1, 100, 5, SetType.working)]),
      ];
      final result = estimateGymExerciseMultipliers(
        sessions,
        1,
        2,
        halfLife: const Duration(days: 30),
        now: DateTime(2026, 1, 2),
      );
      expect(result[1], closeTo(1.0, 0.02));
    });

    test('estimates movement fallback for cold exercise', () {
      final sessions = [
        _session(DateTime(2026, 1, 1), 1, [_set(1, 100, 5, SetType.working)]),
        _session(DateTime(2026, 1, 1), 2, [_set(1, 125, 5, SetType.working)]),
      ];
      final result = estimateGymExerciseMultipliers(
        sessions,
        1,
        2,
        exercises: const {1: 'push', 2: 'push'},
      );
      expect(result[1], closeTo(0.8, 0.001));
      expect(result[2], closeTo(0.8, 0.001));
    });
  });
}
