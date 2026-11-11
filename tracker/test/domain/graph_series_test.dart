import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/models/graph_config.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/services/graph_series.dart';

const _bench = 7;
const _squat = 8;

// A Wednesday.
final _now = DateTime(2026, 11, 11, 18);

WorkoutSet _set(
  double weight,
  double reps, {
  int exercise = _bench,
  SetType type = SetType.working,
}) => WorkoutSet(exerciseId: exercise, weight: weight, reps: reps, type: type);

WorkoutSession _session(
  DateTime start,
  List<WorkoutSet> sets, {
  int gymId = 1,
  String title = 'Push Day',
}) => WorkoutSession(title: title, startTime: start, gymId: gymId, sets: sets);

GraphSeries _series(
  List<WorkoutSession> sessions,
  GraphMetric metric, {
  GraphTimeframe range = GraphTimeframe.all,
  Map<int, double> multipliers = const {},
}) => graphSeries(
  sessions: sessions,
  exerciseId: _bench,
  metric: metric,
  range: range,
  now: _now,
  multipliers: multipliers,
);

void main() {
  group('graphRangeStart', () {
    test('counts calendar months back from now, from the start of the day', () {
      expect(
        graphRangeStart(GraphTimeframe.last30Days, _now),
        DateTime(2026, 10, 11),
      );
      expect(
        graphRangeStart(GraphTimeframe.last90Days, _now),
        DateTime(2026, 8, 11),
      );
      expect(
        graphRangeStart(GraphTimeframe.lastYear, _now),
        DateTime(2025, 11, 11),
      );
      expect(graphRangeStart(GraphTimeframe.all, _now), isNull);
    });

    test('a range ends today, not at the newest session', () {
      // Two months off: the last month holds nothing.
      final series = _series(
        [
          _session(DateTime(2026, 9, 1), [_set(100, 5)]),
        ],
        GraphMetric.best1rm,
        range: GraphTimeframe.last30Days,
      );
      expect(series.isEmpty, isTrue);
      expect(series.latest, isNull);
      expect(series.from, DateTime(2026, 10, 11));
      expect(series.to, _now);
    });
  });

  group('estimated 1RM', () {
    test('is each session best working set of the exercise', () {
      final series = _series([
        _session(DateTime(2026, 11, 3), [
          _set(140, 1, type: SetType.warmup),
          _set(200, 5, exercise: _squat),
          _set(100, 5),
          _set(105, 1),
        ]),
      ], GraphMetric.best1rm);
      final session = series.sessions.single;
      expect(session.value, closeTo(100 * (1 + 5 / 30), 1e-9));
      expect(session.set!.weight, 100);
      expect(session.set!.reps, 5);
      expect(session.sets, 2);
      expect(session.title, 'Push Day');
    });

    test('normalizes by the gym multiplier but keeps the logged set', () {
      final series = _series(
        [
          _session(DateTime(2026, 11, 3), [_set(100, 1)], gymId: 2),
        ],
        GraphMetric.best1rm,
        multipliers: const {2: 0.9},
      );
      expect(series.sessions.single.value, closeTo(90, 1e-9));
      expect(series.sessions.single.set!.weight, 100);
    });

    test('skips sessions without a working set of the exercise', () {
      final series = _series([
        _session(DateTime(2026, 11, 3), [
          _set(60, 10, type: SetType.warmup),
          _set(200, 5, exercise: _squat),
        ]),
      ], GraphMetric.best1rm);
      expect(series.isEmpty, isTrue);
    });

    test('change is newest minus oldest in range', () {
      final series = _series(
        [
          _session(DateTime(2026, 10, 1), [_set(100, 1)]),
          _session(DateTime(2026, 10, 20), [_set(110, 1)]),
          _session(DateTime(2026, 11, 10), [_set(104, 1)]),
        ],
        GraphMetric.best1rm,
        range: GraphTimeframe.last90Days,
      );
      expect(series.latest, 104);
      expect(series.change, 4);
      expect(series.sessions.map((s) => s.isRecord), [true, true, false]);
    });
  });

  group('1RM PR', () {
    final sessions = [
      _session(DateTime(2026, 6, 1), [_set(100, 1)]),
      _session(DateTime(2026, 9, 1), [_set(95, 1)]),
      _session(DateTime(2026, 10, 1), [_set(105, 1)]),
      _session(DateTime(2026, 10, 15), [_set(102, 1)]),
      _session(DateTime(2026, 11, 1), [_set(107.5, 1)]),
    ];

    test('the best climbs only on a new record', () {
      final series = _series(sessions, GraphMetric.record1rm);
      expect(series.sessions.map((s) => s.best), [100, 100, 105, 105, 107.5]);
      expect(series.sessions.map((s) => s.isRecord), [
        true,
        false,
        true,
        false,
        true,
      ]);
      expect(series.latest, 107.5);
      expect(series.change, 7.5);
    });

    test('starts from the best before the range', () {
      final series = _series(
        sessions,
        GraphMetric.record1rm,
        range: GraphTimeframe.last90Days,
      );
      expect(series.bestBefore, 100);
      expect(series.sessions, hasLength(4));
      expect(series.change, 7.5);
    });

    test('with no session in range, the record stands and did not move', () {
      final series = graphSeries(
        sessions: sessions.take(2).toList(),
        exerciseId: _bench,
        metric: GraphMetric.record1rm,
        range: GraphTimeframe.last30Days,
        now: _now,
      );
      expect(series.isEmpty, isTrue);
      expect(series.latest, 100);
      expect(series.change, 0);
    });

    test('one session ever has nothing to compare with', () {
      final series = _series(sessions.take(1).toList(), GraphMetric.record1rm);
      expect(series.latest, 100);
      expect(series.change, isNull);
    });
  });

  group('heaviest weight', () {
    test('is the heaviest set; of equal ones, the one with most reps', () {
      final series = _series([
        _session(DateTime(2026, 11, 3), [
          _set(100, 3),
          _set(100, 6),
          _set(90, 10),
        ]),
      ], GraphMetric.peakWeight);
      final session = series.sessions.single;
      expect(session.value, 100);
      expect(session.set!.reps, 6);
    });
  });

  group('volume', () {
    test('goes by week over 3 months, empty weeks included', () {
      final series = _series(
        [
          // Before the range.
          _session(DateTime(2026, 7, 1), [_set(100, 10)]),
          _session(DateTime(2026, 10, 27), [_set(100, 10), _set(100, 10)]),
          _session(DateTime(2026, 10, 30), [_set(50, 10)]),
          _session(DateTime(2026, 11, 10), [_set(100, 5)]),
        ],
        GraphMetric.volume,
        range: GraphTimeframe.last90Days,
      );
      expect(series.period, GraphPeriod.week);
      // 11 Aug 2026 is a Tuesday: the range snaps back to that Monday.
      expect(series.from, DateTime(2026, 8, 10));
      expect(series.buckets.first.start, DateTime(2026, 8, 10));
      expect(series.buckets.last.start, DateTime(2026, 11, 9));
      expect(series.buckets.last.isCurrent, isTrue);
      expect(series.buckets.length, 14);
      final weekOf26Oct = series.buckets.firstWhere(
        (b) => b.start == DateTime(2026, 10, 26),
      );
      expect(weekOf26Oct.value, 2500);
      expect(weekOf26Oct.sessions, 2);
      expect(series.buckets.where((b) => b.value == 0).length, 12);
      // The headline is the last finished week, not the running one.
      expect(series.headlineBucket!.start, DateTime(2026, 11, 2));
      expect(series.latest, 0);
      expect(series.average, closeTo(2500 / 13, 1e-9));
      expect(series.change, isNull);
    });

    test('goes by month over a year', () {
      final series = _series(
        [
          _session(DateTime(2026, 10, 2), [_set(100, 10)]),
          _session(DateTime(2026, 11, 2), [_set(100, 5)]),
        ],
        GraphMetric.volume,
        range: GraphTimeframe.lastYear,
      );
      expect(series.period, GraphPeriod.month);
      expect(series.from, DateTime(2025, 11));
      expect(series.buckets, hasLength(13));
      expect(series.headlineBucket!.start, DateTime(2026, 10));
      expect(series.latest, 1000);
      expect(series.sessions.last.set, isNull);
      expect(series.sessions.last.sets, 1);
    });

    test('has no columns without a session', () {
      final series = _series(const [], GraphMetric.volume);
      expect(series.buckets, isEmpty);
      expect(series.latest, isNull);
    });
  });
}
