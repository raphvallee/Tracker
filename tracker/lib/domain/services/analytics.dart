library;

import 'dart:math' as math;

import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';

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

/// Reps in reserve count up to this many: a set rated easier than RPE 6 is
/// too far from failure for its rating to say much.
const double maxRepsInReserve = 4;

/// [reps] plus the reps a set rated [rpe] had left in reserve (10 minus it,
/// at most [maxRepsInReserve]): 8 reps at RPE 7 count as 11. A set without
/// a rating counts its reps.
double effectiveRepsOf(double reps, double? rpe) => rpe == null
    ? reps
    : reps + math.min(maxRepsInReserve, math.max(0.0, 10 - rpe));

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

class AnalyticsService {
  final Map<_AnalyticsKey, AnalyticsSnapshot> _cache = {};

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

  void clear() => _cache.clear();

  int get cacheSize => _cache.length;

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
