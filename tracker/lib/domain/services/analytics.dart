/// Pure analytics for progression/multipliers (Plan.md §2.3, §2.4).
library;

import 'dart:math' as math;

import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/models/graph_config.dart';

/// Returns the beginning of the requested graph range, relative to the newest
/// session. The all-time range returns null.
DateTime? graphRangeStart(GraphTimeframe timeframe, DateTime newest) {
  switch (timeframe) {
    case GraphTimeframe.all:
      return null;
    case GraphTimeframe.last30Days:
      return newest.subtract(const Duration(days: 30));
    case GraphTimeframe.last90Days:
      return newest.subtract(const Duration(days: 90));
    case GraphTimeframe.lastYear:
      return newest.subtract(const Duration(days: 365));
  }
}

String graphMetricLabel(GraphMetric metric) {
  switch (metric) {
    case GraphMetric.best1rm:
      return 'Best 1RM';
    case GraphMetric.peakWeight:
      return 'Peak weight';
    case GraphMetric.volume:
      return 'Volume';
  }
}

String graphTimeframeLabel(GraphTimeframe timeframe) {
  switch (timeframe) {
    case GraphTimeframe.all:
      return 'All time';
    case GraphTimeframe.last30Days:
      return 'Last 30 days';
    case GraphTimeframe.last90Days:
      return 'Last 90 days';
    case GraphTimeframe.lastYear:
      return 'Last year';
  }
}

List<WorkoutSession> sessionsForTimeframe(
  List<WorkoutSession> sessions,
  GraphTimeframe timeframe,
) {
  if (sessions.isEmpty || timeframe == GraphTimeframe.all) return sessions;
  final newest = sessions
      .map((session) => session.startTime)
      .reduce((a, b) => a.isAfter(b) ? a : b);
  final start = graphRangeStart(timeframe, newest)!;
  return sessions
      .where((session) => !session.startTime.isBefore(start))
      .toList();
}

List<ProgressionPoint> graphSeries({
  required List<WorkoutSession> sessions,
  required Map<int, double> multipliers,
  required GraphMetric metric,
  int? exerciseId,
  GraphTimeframe timeframe = GraphTimeframe.all,
}) {
  final filtered = sessionsForTimeframe(sessions, timeframe);
  switch (metric) {
    case GraphMetric.best1rm:
      return exerciseBest1rm(filtered, multipliers, exerciseId);
    case GraphMetric.peakWeight:
      return exercisePeakWeight(filtered, multipliers, exerciseId);
    case GraphMetric.volume:
      return volumeTrend(filtered, multipliers, exerciseId);
  }
}

String graphMetricUnit(GraphMetric metric) =>
    metric == GraphMetric.volume ? 'kg·reps' : 'kg';

String graphMetricTitle(GraphConfig config) => config.title.trim();

/// A graph-ready series for a persisted configuration.
List<ProgressionPoint> graphPoints({
  required GraphConfig config,
  required List<WorkoutSession> sessions,
  required Map<int, double> multipliers,
}) => graphSeries(
  sessions: sessions,
  multipliers: multipliers,
  metric: config.metric,
  exerciseId: config.exerciseId,
  timeframe: config.timeframe,
);

/// Scales a raw weight using an exercise override, then the gym fallback.
///
/// [exerciseMultipliers] is keyed by gym id and then exercise id. The optional
/// positional [exerciseId] keeps existing callers source-compatible.
double normalizedWeight(
  double raw,
  Map<int, double> multipliers,
  int? gymId, [
  int? exerciseId,
  Map<int, Map<int, double>> exerciseMultipliers = const {},
]) {
  final exercise = gymId == null || exerciseId == null
      ? null
      : exerciseMultipliers[gymId]?[exerciseId];
  return raw * (exercise ?? multipliers[gymId] ?? 1.0);
}

typedef PerGymExerciseMultipliers = Map<int, Map<int, double>>;

Map<int, double> flattenExerciseMultipliers(
  int gymId,
  Map<int, double> values,
) => {for (final entry in values.entries) entry.key: entry.value};

double epley1rm({required double weight, required double reps}) =>
    reps <= 1 ? weight : weight * (1 + reps / 30);

class ProgressionPoint {
  const ProgressionPoint({required this.date, required this.value});

  final DateTime date;
  final double value;
}

class ExerciseSummary {
  const ExerciseSummary({
    required this.best1rm,
    required this.peakVolume,
    required this.sessionCount,
  });

  final double best1rm;
  final double peakVolume;
  final int sessionCount;
}

/// An immutable, internally consistent result of one analytics calculation.
/// Lists and maps are defensive unmodifiable copies, so a snapshot can safely
/// be retained by a widget between repository updates.
class AnalyticsSnapshot {
  AnalyticsSnapshot({
    required List<ProgressionPoint> best1rm,
    required List<ProgressionPoint> peakWeight,
    required List<ProgressionPoint> volume,
    required this.summary,
    required this.exerciseId,
    required this.revision,
  }) : best1rm = List.unmodifiable(best1rm),
       peakWeight = List.unmodifiable(peakWeight),
       volume = List.unmodifiable(volume);

  final int? exerciseId;
  final Object? revision;
  final List<ProgressionPoint> best1rm;
  final List<ProgressionPoint> peakWeight;
  final List<ProgressionPoint> volume;
  final ExerciseSummary summary;
}

/// Memoizes snapshots by the complete session content, gym multipliers, and
/// optional caller revision/filter. The content fingerprint means callers may
/// safely reuse a service while repositories replace or mutate list instances.
class AnalyticsService {
  final Map<_AnalyticsKey, AnalyticsSnapshot> _cache = {};

  /// Computes all snapshot metrics in one pass over each session's sets.
  AnalyticsSnapshot _computeSnapshot({
    required List<WorkoutSession> sessions,
    required Map<int, double> multipliers,
    required int? exerciseId,
    required Object? revision,
    required PerGymExerciseMultipliers exerciseMultipliers,
  }) {
    final best1rm = <ProgressionPoint>[];
    final peakWeight = <ProgressionPoint>[];
    final volume = <ProgressionPoint>[];
    var best = 0.0;
    var peakVolume = 0.0;
    var sessionCount = 0;

    for (final session in sessions) {
      var sessionBest = 0.0;
      var sessionVolume = 0.0;
      var selectedVolume = 0.0;
      var hasSelectedSets = false;
      var selectedPeakWeight = 0.0;
      var hasWorkingSets = false;

      for (final set in session.sets) {
        if (set.isWarmup) continue;
        final weight = normalizedWeight(
          set.weight,
          multipliers,
          session.gymId,
          set.exerciseId,
          exerciseMultipliers,
        );
        sessionVolume += weight * set.reps;
        hasWorkingSets = true;
        if (exerciseId != null && set.exerciseId != exerciseId) continue;
        hasSelectedSets = true;
        selectedVolume += weight * set.reps;
        if (weight > selectedPeakWeight) selectedPeakWeight = weight;
        final oneRm = epley1rm(weight: weight, reps: set.reps);
        if (oneRm > sessionBest) sessionBest = oneRm;
      }

      if (hasWorkingSets) {
        volume.add(
          ProgressionPoint(date: session.startTime, value: sessionVolume),
        );
      }
      if (!hasSelectedSets) continue;

      sessionCount++;
      best1rm.add(
        ProgressionPoint(date: session.startTime, value: sessionBest),
      );
      peakWeight.add(
        ProgressionPoint(date: session.startTime, value: selectedPeakWeight),
      );
      if (sessionBest > best) best = sessionBest;
      if (selectedVolume > peakVolume) peakVolume = selectedVolume;
    }

    best1rm.sort((a, b) => a.date.compareTo(b.date));
    peakWeight.sort((a, b) => a.date.compareTo(b.date));
    volume.sort((a, b) => a.date.compareTo(b.date));
    return AnalyticsSnapshot(
      best1rm: best1rm,
      peakWeight: peakWeight,
      volume: volume,
      summary: ExerciseSummary(
        best1rm: best,
        peakVolume: peakVolume,
        sessionCount: sessionCount,
      ),
      exerciseId: exerciseId,
      revision: revision,
    );
  }

  AnalyticsSnapshot snapshot({
    required List<WorkoutSession> sessions,
    required Map<int, double> multipliers,
    int? exerciseId,
    Object? revision,
    PerGymExerciseMultipliers exerciseMultipliers = const {},
  }) {
    final key = _AnalyticsKey(
      _fingerprint(sessions),
      Object.hash(
        _mapFingerprint(multipliers),
        _nestedMapFingerprint(exerciseMultipliers),
      ),
      exerciseId,
      revision,
    );
    return _cache[key] ??= _computeSnapshot(
      sessions: sessions,
      multipliers: multipliers,
      exerciseId: exerciseId,
      revision: revision,
      exerciseMultipliers: exerciseMultipliers,
    );
  }

  /// Removes cached snapshots, allowing retained session data to be released.
  void clear() => _cache.clear();

  /// Number of cached snapshots, exposed for diagnostics and tests.
  int get cacheSize => _cache.length;

  /// Alias useful at call sites that treat this as a computation service.
  AnalyticsSnapshot compute({
    required List<WorkoutSession> sessions,
    required Map<int, double> multipliers,
    int? exerciseId,
    Object? revision,
    PerGymExerciseMultipliers exerciseMultipliers = const {},
  }) => snapshot(
    sessions: sessions,
    multipliers: multipliers,
    exerciseId: exerciseId,
    revision: revision,
    exerciseMultipliers: exerciseMultipliers,
  );
}

class _AnalyticsKey {
  const _AnalyticsKey(
    this.sessions,
    this.multipliers,
    this.exerciseId,
    this.revision,
  );

  final int sessions;
  final int multipliers;
  final int? exerciseId;
  final Object? revision;

  @override
  int get hashCode => Object.hash(sessions, multipliers, exerciseId, revision);

  @override
  bool operator ==(Object other) =>
      other is _AnalyticsKey &&
      sessions == other.sessions &&
      multipliers == other.multipliers &&
      exerciseId == other.exerciseId &&
      revision == other.revision;
}

int _fingerprint(List<WorkoutSession> sessions) {
  var hash = 17;
  for (final s in sessions) {
    hash = Object.hash(
      hash,
      s.id,
      s.title,
      s.startTime.microsecondsSinceEpoch,
      s.endTime?.microsecondsSinceEpoch,
      s.gymId,
    );
    for (final set in s.sets) {
      hash = Object.hash(
        hash,
        set.exerciseId,
        set.weight,
        set.reps,
        set.type.index,
      );
    }
  }
  return hash;
}

int _mapFingerprint(Map<int, double> map) {
  var hash = 17;
  final entries = map.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  for (final e in entries) {
    hash = Object.hash(hash, e.key, e.value);
  }
  return hash;
}

int _nestedMapFingerprint(PerGymExerciseMultipliers map) {
  var hash = 17;
  final gyms = map.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  for (final gym in gyms) {
    hash = Object.hash(hash, gym.key, _mapFingerprint(gym.value));
  }
  return hash;
}

Iterable<WorkoutSet> _workingSets(WorkoutSession s) =>
    s.sets.where((set) => !set.isWarmup);

List<ProgressionPoint> exerciseBest1rm(
  List<WorkoutSession> sessions,
  Map<int, double> multipliers,
  int? exerciseId, [
  PerGymExerciseMultipliers exerciseMultipliers = const {},
]) {
  final points = <ProgressionPoint>[];
  for (final session in sessions) {
    final sets = _workingSets(session)
        .where((set) => exerciseId == null || set.exerciseId == exerciseId);
    if (sets.isEmpty) continue;
    final best = sets
        .map(
          (s) => epley1rm(
            weight: normalizedWeight(
              s.weight,
              multipliers,
              session.gymId,
              s.exerciseId,
              exerciseMultipliers,
            ),
            reps: s.reps,
          ),
        )
        .reduce((a, b) => a > b ? a : b);
    points.add(ProgressionPoint(date: session.startTime, value: best));
  }
  points.sort((a, b) => a.date.compareTo(b.date));
  return points;
}

List<ProgressionPoint> exercisePeakWeight(
  List<WorkoutSession> sessions,
  Map<int, double> multipliers,
  int? exerciseId, [
  PerGymExerciseMultipliers exerciseMultipliers = const {},
]) {
  final points = <ProgressionPoint>[];
  for (final session in sessions) {
    final sets = _workingSets(session)
        .where((set) => exerciseId == null || set.exerciseId == exerciseId);
    if (sets.isEmpty) continue;
    points.add(
      ProgressionPoint(
        date: session.startTime,
        value: sets
            .map(
              (s) => normalizedWeight(
                s.weight,
                multipliers,
                session.gymId,
                s.exerciseId,
                exerciseMultipliers,
              ),
            )
            .reduce((a, b) => a > b ? a : b),
      ),
    );
  }
  points.sort((a, b) => a.date.compareTo(b.date));
  return points;
}

List<ProgressionPoint> volumeTrend(
  List<WorkoutSession> sessions,
  Map<int, double> multipliers, [
  int? exerciseId,
  PerGymExerciseMultipliers exerciseMultipliers = const {},
]) {
  final points = <ProgressionPoint>[];
  for (final session in sessions) {
    final sets = _workingSets(session)
        .where((set) => exerciseId == null || set.exerciseId == exerciseId);
    if (sets.isEmpty) continue;
    points.add(
      ProgressionPoint(
        date: session.startTime,
        value: sets.fold(
          0.0,
          (sum, s) =>
              sum +
              normalizedWeight(
                    s.weight,
                    multipliers,
                    session.gymId,
                    s.exerciseId,
                    exerciseMultipliers,
                  ) *
                  s.reps,
        ),
      ),
    );
  }
  points.sort((a, b) => a.date.compareTo(b.date));
  return points;
}

ExerciseSummary exerciseSummary(
  List<WorkoutSession> sessions,
  Map<int, double> multipliers,
  int? exerciseId, [
  PerGymExerciseMultipliers exerciseMultipliers = const {},
]) {
  var count = 0;
  var peak = 0.0;
  var best = 0.0;
  for (final session in sessions) {
    final sets = _workingSets(session)
        .where((s) => exerciseId == null || s.exerciseId == exerciseId);
    if (sets.isEmpty) continue;
    count++;
    var volume = 0.0;
    for (final set in sets) {
      final weight = normalizedWeight(
        set.weight,
        multipliers,
        session.gymId,
        set.exerciseId,
        exerciseMultipliers,
      );
      volume += weight * set.reps;
      final oneRm = epley1rm(weight: weight, reps: set.reps);
      if (oneRm > best) best = oneRm;
    }
    if (volume > peak) peak = volume;
  }
  return ExerciseSummary(best1rm: best, peakVolume: peak, sessionCount: count);
}

/// Estimates a gym-wide multiplier using the median ratio of shared exercises.
/// The legacy calculation remains the default; pass [halfLife] to apply
/// exponential recency weighting to observations.
double? estimateGymMultiplier(
  List<WorkoutSession> sessions,
  int? primaryGymId,
  int gymId, {
  Duration? halfLife,
  DateTime? now,
}) {
  final estimates = estimateGymExerciseMultipliers(
    sessions,
    primaryGymId,
    gymId,
    halfLife: halfLife ?? const Duration(days: 180),
    now: now,
  );
  if (estimates.isEmpty) return null;
  return _median(estimates.values.toList());
}

/// Returns one time-weighted multiplier per exercise shared by both gyms.
/// Recent observations receive exponentially higher weight. A missing shared
/// exercise can be represented by a movement fallback via [exercises].
Map<int, double> estimateGymExerciseMultipliers(
  List<WorkoutSession> sessions,
  int? primaryGymId,
  int gymId, {
  Duration halfLife = const Duration(days: 180),
  DateTime? now,
  Map<int, Object>? exercises,
}) {
  final latest = now ?? _latestSessionDate(sessions) ?? DateTime.now();
  final primary = <int, List<_WeightedValue>>{};
  final secondary = <int, List<_WeightedValue>>{};
  for (final session in sessions) {
    final bucket = session.gymId == primaryGymId
        ? primary
        : (session.gymId == gymId ? secondary : null);
    if (bucket == null) continue;
    final ageDays = latest.difference(session.startTime).inHours / 24;
    final weight = halfLife.inHours <= 0
        ? 1.0
        : _expDecay(ageDays < 0 ? 0 : ageDays, halfLife.inHours / 24);
    for (final set in _workingSets(session)) {
      bucket
          .putIfAbsent(set.exerciseId, () => [])
          .add(_WeightedValue(set.weight, weight));
    }
  }
  final result = <int, double>{};
  final ratiosByGroup = <Object, List<double>>{};
  for (final entry in primary.entries) {
    final other = secondary[entry.key];
    if (other == null || other.isEmpty) continue;
    final a = _weightedMean(entry.value);
    final b = _weightedMean(other);
    if (a > 0 && b > 0) {
      final ratio = a / b;
      result[entry.key] = ratio;
      final group = exercises?[entry.key];
      if (group != null) ratiosByGroup.putIfAbsent(group, () => []).add(ratio);
    }
  }
  if (exercises != null) {
    for (final entry in exercises.entries) {
      if (result.containsKey(entry.key)) continue;
      final fallback = ratiosByGroup[entry.value];
      if (fallback != null && fallback.isNotEmpty) {
        result[entry.key] = _median(fallback);
      }
    }
  }
  return result;
}

class _WeightedValue {
  const _WeightedValue(this.value, this.weight);
  final double value;
  final double weight;
}

double _weightedMean(List<_WeightedValue> values) {
  var total = 0.0;
  var weights = 0.0;
  for (final value in values) {
    total += value.value * value.weight;
    weights += value.weight;
  }
  return weights == 0 ? 0 : total / weights;
}

double _expDecay(double ageDays, double halfLifeDays) =>
    ageDays == 0 ? 1 : math.pow(0.5, ageDays / halfLifeDays).toDouble();

DateTime? _latestSessionDate(List<WorkoutSession> sessions) => sessions.isEmpty
    ? null
    : sessions.map((s) => s.startTime).reduce((a, b) => a.isAfter(b) ? a : b);

double _median(List<double> values) {
  final sorted = [...values]..sort();
  return sorted[sorted.length ~/ 2];
}
