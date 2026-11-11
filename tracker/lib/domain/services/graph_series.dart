import 'package:tracker/domain/models/graph_config.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/services/analytics.dart';

/// Where [range] starts: the start of the day that many calendar months
/// before [now]; null for all time.
DateTime? graphRangeStart(GraphTimeframe range, DateTime now) {
  final months = switch (range) {
    GraphTimeframe.all => null,
    GraphTimeframe.last30Days => 1,
    GraphTimeframe.last90Days => 3,
    GraphTimeframe.lastYear => 12,
  };
  if (months == null) return null;
  return DateTime(now.year, now.month - months, now.day);
}

/// How volume is grouped: by week over a month or three, by month beyond.
enum GraphPeriod { week, month }

/// The Monday (or the 1st) that starts the [period] holding [date].
DateTime graphPeriodStart(DateTime date, GraphPeriod period) =>
    switch (period) {
      GraphPeriod.week => DateTime(
        date.year,
        date.month,
        date.day - (date.weekday - 1),
      ),
      GraphPeriod.month => DateTime(date.year, date.month),
    };

DateTime _nextPeriod(DateTime start, GraphPeriod period) => switch (period) {
  GraphPeriod.week => DateTime(start.year, start.month, start.day + 7),
  GraphPeriod.month => DateTime(start.year, start.month + 1),
};

/// The set a session's value came from, as logged (not normalized).
class GraphSet {
  const GraphSet({required this.weight, required this.reps});

  final double weight;
  final double reps;
}

/// One session of a graph's exercise.
class GraphSession {
  const GraphSession({
    required this.date,
    required this.value,
    required this.best,
    required this.isRecord,
    required this.sessionId,
    required this.title,
    required this.sets,
    this.set,
  });

  final DateTime date;

  /// What the session scored on the graph's metric, in kilograms.
  final double value;

  /// The highest [value] up to and including this session, all time.
  final double best;

  /// Whether [value] beat every earlier session (the first one does).
  final bool isRecord;

  final int sessionId;
  final String title;

  /// Working sets of the exercise in the session.
  final int sets;

  /// The set behind [value]; null for volume, which sums them all.
  final GraphSet? set;
}

/// A week or a month of volume.
class GraphBucket {
  const GraphBucket({
    required this.start,
    required this.value,
    required this.sessions,
    required this.isCurrent,
  });

  final DateTime start;
  final double value;
  final int sessions;

  /// The week or month still running.
  final bool isCurrent;
}

/// What one graph plots over its range, plus what its headline reads.
class GraphSeries {
  const GraphSeries({
    required this.metric,
    required this.range,
    required this.from,
    required this.to,
    required this.sessions,
    this.bestBefore,
    this.period,
    this.buckets = const [],
  });

  final GraphMetric metric;
  final GraphTimeframe range;

  /// Where the time axis starts: the range start (a week or month start for
  /// volume), or the first session for all time.
  final DateTime from;
  final DateTime to;

  /// The sessions in range, oldest first.
  final List<GraphSession> sessions;

  /// The highest value before the range; null when nothing came before.
  final double? bestBefore;

  /// Volume only: the period its columns stand for, and the columns, oldest
  /// first, empty weeks or months included.
  final GraphPeriod? period;
  final List<GraphBucket> buckets;

  bool get isEmpty => sessions.isEmpty;

  /// What the headline shows at rest: the newest session's value, the best
  /// ever for a record graph, the last finished week or month for volume.
  double? get latest {
    switch (metric) {
      case GraphMetric.volume:
        return headlineBucket?.value;
      case GraphMetric.record1rm:
        return sessions.isEmpty ? bestBefore : sessions.last.best;
      case GraphMetric.best1rm:
      case GraphMetric.peakWeight:
        return sessions.isEmpty ? null : sessions.last.value;
    }
  }

  /// How far [latest] moved over the range; null when there is nothing to
  /// compare it with. A record graph compares the best at both ends.
  double? get change {
    switch (metric) {
      case GraphMetric.volume:
        return null;
      case GraphMetric.record1rm:
        if (sessions.isEmpty) return bestBefore == null ? null : 0;
        final start = bestBefore;
        if (start == null) {
          return sessions.length < 2
              ? null
              : sessions.last.best - sessions.first.value;
        }
        return sessions.last.best - start;
      case GraphMetric.best1rm:
      case GraphMetric.peakWeight:
        return sessions.length < 2
            ? null
            : sessions.last.value - sessions.first.value;
    }
  }

  /// Volume: the last finished week or month, or the running one when none
  /// has finished yet.
  GraphBucket? get headlineBucket {
    if (sessions.isEmpty || buckets.isEmpty) return null;
    for (final bucket in buckets.reversed) {
      if (!bucket.isCurrent) return bucket;
    }
    return buckets.last;
  }

  /// Volume: the average finished week or month, empty ones included.
  double? get average {
    final finished = [
      for (final bucket in buckets)
        if (!bucket.isCurrent) bucket.value,
    ];
    if (finished.isEmpty) return null;
    return finished.reduce((a, b) => a + b) / finished.length;
  }
}

/// The graph of [metric] for [exerciseId] (every exercise when null) over
/// [range] up to [now]. Warm-ups are left out and weights are normalized by
/// each gym's multiplier.
GraphSeries graphSeries({
  required List<WorkoutSession> sessions,
  required int? exerciseId,
  required GraphMetric metric,
  required GraphTimeframe range,
  required DateTime now,
  Map<int, double> multipliers = const {},
  PerGymExerciseMultipliers exerciseMultipliers = const {},
}) {
  final ordered = [...sessions]
    ..sort((a, b) => a.startTime.compareTo(b.startTime));
  final all = <GraphSession>[];
  var best = double.negativeInfinity;
  for (final session in ordered) {
    final measured = _measure(
      session,
      exerciseId,
      metric,
      multipliers,
      exerciseMultipliers,
    );
    if (measured == null) continue;
    final isRecord = measured.value > best;
    if (isRecord) best = measured.value;
    all.add(
      GraphSession(
        date: session.startTime,
        value: measured.value,
        best: best,
        isRecord: isRecord,
        sessionId: session.id,
        title: session.title,
        sets: measured.sets,
        set: measured.set,
      ),
    );
  }

  final period = metric != GraphMetric.volume
      ? null
      : range == GraphTimeframe.last30Days || range == GraphTimeframe.last90Days
      ? GraphPeriod.week
      : GraphPeriod.month;
  var from =
      graphRangeStart(range, now) ?? (all.isEmpty ? now : all.first.date);
  from = period == null
      ? DateTime(from.year, from.month, from.day)
      : graphPeriodStart(from, period);
  final shown = [
    for (final session in all)
      if (!session.date.isBefore(from)) session,
  ];
  final before = all.length - shown.length;
  return GraphSeries(
    metric: metric,
    range: range,
    from: from,
    to: now,
    sessions: shown,
    bestBefore: before == 0 ? null : all[before - 1].best,
    period: period,
    buckets: period == null || all.isEmpty
        ? const []
        : _buckets(shown, from, now, period),
  );
}

({double value, int sets, GraphSet? set})? _measure(
  WorkoutSession session,
  int? exerciseId,
  GraphMetric metric,
  Map<int, double> multipliers,
  PerGymExerciseMultipliers exerciseMultipliers,
) {
  var count = 0;
  var total = 0.0;
  double? best;
  GraphSet? top;
  for (final set in session.sets) {
    if (set.isWarmup) continue;
    if (exerciseId != null && set.exerciseId != exerciseId) continue;
    count++;
    final weight = normalizedWeight(
      set.weight,
      multipliers,
      session.gymId,
      set.exerciseId,
      exerciseMultipliers,
    );
    final value = switch (metric) {
      GraphMetric.volume => weight * set.reps,
      GraphMetric.peakWeight => weight,
      GraphMetric.best1rm ||
      GraphMetric.record1rm => epley1rm(weight: weight, reps: set.reps),
    };
    total += value;
    // Of equally heavy sets, the one with the most reps tells most.
    if (best == null ||
        value > best ||
        (value == best && set.reps > top!.reps)) {
      best = value;
      top = GraphSet(weight: set.weight, reps: set.reps);
    }
  }
  if (count == 0) return null;
  return metric == GraphMetric.volume
      ? (value: total, sets: count, set: null)
      : (value: best!, sets: count, set: top);
}

List<GraphBucket> _buckets(
  List<GraphSession> sessions,
  DateTime from,
  DateTime now,
  GraphPeriod period,
) {
  final current = graphPeriodStart(now, period);
  final buckets = <GraphBucket>[];
  var i = 0;
  for (
    var start = from;
    !start.isAfter(current);
    start = _nextPeriod(start, period)
  ) {
    final end = _nextPeriod(start, period);
    var value = 0.0;
    var count = 0;
    while (i < sessions.length && sessions[i].date.isBefore(end)) {
      value += sessions[i].value;
      count++;
      i++;
    }
    buckets.add(
      GraphBucket(
        start: start,
        value: value,
        sessions: count,
        isCurrent: start == current,
      ),
    );
  }
  return buckets;
}
