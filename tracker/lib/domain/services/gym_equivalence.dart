import 'dart:math' as math;

import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/services/analytics.dart';

// The same weight can feel lighter or heavier from gym to gym on machines
// and cables (pulleys, cams, stacks), never on plates or dumbbells. Each gym
// keeps a factor per machine: home kilograms per kilogram there, so 0.9
// means 100 kg there is 90 kg at home. The primary gym is home, at 1.

/// Whether [equipment]'s weights differ from gym to gym: machines and
/// cables do.
bool convertsAcrossGyms(List<Equipment> equipment) =>
    equipment.contains(Equipment.machine) ||
    equipment.contains(Equipment.cable);

/// Factors outside this range are taken for a mistake, not a gym.
const double minGymFactor = 0.5;
const double maxGymFactor = 2.0;

/// A factor worked out from workouts at two gyms.
class FactorEstimate {
  const FactorEstimate({
    required this.factor,
    required this.samples,
    required this.spread,
  });

  final double factor;

  /// The workouts at the other gym it came from.
  final int samples;

  /// How far those workouts typically sit from [factor].
  final double spread;
}

const double _bandwidthDays = 45;
const double _windowDays = 180;
const double _extrapolationDays = 30;
const double _minTrendSpanDays = 7;

/// The most a trend may climb or fall per day, as a share of its level:
/// 12% a month. Two close noisy workouts must not make a steep line.
const double _maxDailyChange = 0.004;

/// Reps above this count as this many in the estimated 1RM, where Epley
/// stops being a fair guess.
const double _repCap = 12;

/// [exerciseId]'s factor at [gymId] against [homeGymId], from the user's
/// trend: each workout at [gymId] is set against the home estimated 1RM the
/// trend predicts for its day (a line through the home workouts around it,
/// carried at most a month past them), so getting stronger between two
/// visits never reads as a lighter gym. The factor is the recency-weighted
/// median of those ratios. Null without a workout at [gymId] with home
/// workouts near enough to compare with. With [effectiveReps], a rated set
/// also counts the reps it had left ([effectiveRepsOf]), so going easier on
/// an unfamiliar machine never reads as a heavier one.
FactorEstimate? estimateExerciseFactor(
  List<WorkoutSession> sessions, {
  required int exerciseId,
  required int homeGymId,
  required int gymId,
  DateTime? now,
  Duration halfLife = const Duration(days: 180),
  bool effectiveReps = false,
}) {
  final home = <_Point>[];
  final away = <_Point>[];
  DateTime? latest;
  for (final session in sessions) {
    final bucket = session.gymId == homeGymId
        ? home
        : session.gymId == gymId
        ? away
        : null;
    if (bucket == null) continue;
    final best = _bestOneRm(session, exerciseId, effectiveReps: effectiveReps);
    if (best == null) continue;
    bucket.add(_Point(_dayOf(session.startTime), best));
    if (latest == null || session.startTime.isAfter(latest)) {
      latest = session.startTime;
    }
  }
  if (home.isEmpty || away.isEmpty) return null;
  final today = _dayOf(now ?? latest!);
  final halfLifeDays = halfLife.inHours / 24;
  final ratios = <_Weighted>[];
  for (final point in away) {
    final predicted = _trendAt(home, point.day);
    if (predicted == null || predicted <= 0) continue;
    final ratio = predicted / point.value;
    if (ratio < minGymFactor || ratio > maxGymFactor) continue;
    final age = math.max(0.0, today - point.day);
    final weight = halfLifeDays <= 0
        ? 1.0
        : math.pow(0.5, age / halfLifeDays).toDouble();
    ratios.add(_Weighted(ratio, weight));
  }
  if (ratios.isEmpty) return null;
  final factor = _weightedMedian(ratios);
  final spread = _weightedMedian([
    for (final ratio in ratios)
      _Weighted((ratio.value - factor).abs(), ratio.weight),
  ]);
  return FactorEstimate(factor: factor, samples: ratios.length, spread: spread);
}

/// The best working set of [exerciseId] in [session] as an estimated 1RM;
/// null when it has none with a weight. With [effectiveReps], a rated set's
/// reps in reserve count on top of its capped reps.
double? _bestOneRm(
  WorkoutSession session,
  int exerciseId, {
  bool effectiveReps = false,
}) {
  double? best;
  for (final set in session.sets) {
    if (set.exerciseId != exerciseId || set.isWarmup || set.weight <= 0) {
      continue;
    }
    final reps = math.min(set.reps, _repCap);
    final oneRm = epley1rm(
      weight: set.weight,
      reps: effectiveReps ? effectiveRepsOf(reps, set.rpe) : reps,
    );
    if (best == null || oneRm > best) best = oneRm;
  }
  return best;
}

/// The home estimated 1RM the trend gives for [day]: a line weighted to the
/// home workouts nearest it, within half a year. Null when there are none.
double? _trendAt(List<_Point> home, double day) {
  final near = [
    for (final point in home)
      if ((point.day - day).abs() <= _windowDays) point,
  ];
  if (near.isEmpty) return null;
  var first = near.first.day;
  var last = near.first.day;
  for (final point in near) {
    first = math.min(first, point.day);
    last = math.max(last, point.day);
  }
  final at = day.clamp(first - _extrapolationDays, last + _extrapolationDays);
  double weightOf(_Point point) {
    final distance = (point.day - at) / _bandwidthDays;
    return math.exp(-0.5 * distance * distance);
  }

  var total = 0.0;
  var sumDay = 0.0;
  var sumValue = 0.0;
  for (final point in near) {
    final weight = weightOf(point);
    total += weight;
    sumDay += weight * point.day;
    sumValue += weight * point.value;
  }
  final meanDay = sumDay / total;
  final meanValue = sumValue / total;
  var spreadDays = 0.0;
  var covariance = 0.0;
  for (final point in near) {
    final weight = weightOf(point);
    spreadDays += weight * (point.day - meanDay) * (point.day - meanDay);
    covariance += weight * (point.day - meanDay) * (point.value - meanValue);
  }
  final variance = spreadDays / total;
  if (variance < _minTrendSpanDays * _minTrendSpanDays) return meanValue;
  final limit = meanValue * _maxDailyChange;
  final slope = (covariance / spreadDays).clamp(-limit, limit);
  return meanValue + slope * (at - meanDay);
}

/// One session of an exercise on its trend across gyms: its best working
/// set as an estimated 1RM, as logged and as at the primary gym.
class GymTrendPoint {
  const GymTrendPoint({
    required this.date,
    required this.gymId,
    required this.logged,
    required this.atHome,
  });

  final DateTime date;
  final int? gymId;
  final double logged;
  final double atHome;
}

/// [exerciseId]'s sessions as [GymTrendPoint]s, oldest first, each brought
/// home by its gym's factor (see [gymFactorOf]). [effectiveReps] reads sets
/// as [estimateExerciseFactor] does.
List<GymTrendPoint> gymTrendOf(
  List<WorkoutSession> sessions,
  int exerciseId,
  List<Gym> gyms, {
  bool effectiveReps = false,
}) {
  final byId = {for (final gym in gyms) gym.id: gym};
  final points = <GymTrendPoint>[];
  for (final session in sessions) {
    final best = _bestOneRm(session, exerciseId, effectiveReps: effectiveReps);
    if (best == null) continue;
    final gym = byId[session.gymId];
    final factor = gym == null ? 1.0 : gymFactorOf(gym, exerciseId).value;
    points.add(
      GymTrendPoint(
        date: session.startTime,
        gymId: session.gymId,
        logged: best,
        atHome: best * factor,
      ),
    );
  }
  return points..sort((a, b) => a.date.compareTo(b.date));
}

/// The home trend through [points] at [date]: the line
/// [estimateExerciseFactor] measures other gyms against. Null far from any
/// workout at [homeGymId].
double? homeTrendAt(List<GymTrendPoint> points, int homeGymId, DateTime date) {
  final home = [
    for (final point in points)
      if (point.gymId == homeGymId) _Point(_dayOf(point.date), point.logged),
  ];
  return home.isEmpty ? null : _trendAt(home, _dayOf(date));
}

double _dayOf(DateTime time) =>
    time.millisecondsSinceEpoch / Duration.millisecondsPerDay;

class _Point {
  const _Point(this.day, this.value);

  final double day;
  final double value;
}

class _Weighted {
  const _Weighted(this.value, this.weight);

  final double value;
  final double weight;
}

double _weightedMedian(List<_Weighted> values) {
  final sorted = [...values]..sort((a, b) => a.value.compareTo(b.value));
  final total = sorted.fold(0.0, (sum, value) => sum + value.weight);
  var running = 0.0;
  for (final value in sorted) {
    running += value.weight;
    if (running >= total / 2) return value.value;
  }
  return sorted.last.value;
}

double _median(List<double> values) {
  final sorted = [...values]..sort();
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
}

/// Where a factor comes from.
enum FactorSource {
  /// The primary gym: the baseline, always 1.
  home,

  /// Set by hand.
  manual,

  /// Estimated from workouts at both gyms.
  estimated,

  /// Not trained here yet: the gym's overall factor.
  gym,
}

/// One machine's factor at one gym, and where it comes from.
class GymFactor {
  const GymFactor(
    this.value,
    this.source, {
    this.samples = 0,
    this.spread = 0,
    this.estimate,
  });

  static const home = GymFactor(1, FactorSource.home);

  final double value;
  final FactorSource source;

  /// The workouts the estimate came from.
  final int samples;
  final double spread;

  /// The estimate, also kept while a factor set by hand is in use.
  final double? estimate;

  /// How far [value] may be off: nothing at home or for a factor set by
  /// hand, the workouts' spread for an estimate (at least 5% for one
  /// workout, narrowing with more), and a tenth for a gym's overall factor.
  double get band => switch (source) {
    FactorSource.home || FactorSource.manual => 0,
    FactorSource.estimated => math.max(
      spread,
      0.05 / math.sqrt(math.max(samples, 1)),
    ),
    FactorSource.gym => 0.1,
  };
}

/// [exerciseId]'s factor at [gym]: 1 at the primary gym, else the one set
/// by hand, the estimate, or the gym's overall factor.
GymFactor gymFactorOf(Gym gym, int exerciseId) {
  if (gym.isPrimary) return GymFactor.home;
  final row = _rowOf(gym.perExerciseMultipliers, exerciseId);
  if (row == null) return GymFactor(gym.multiplier, FactorSource.gym);
  return GymFactor(
    row.multiplier,
    row.manual ? FactorSource.manual : FactorSource.estimated,
    samples: row.samples,
    spread: row.spread,
    estimate: _estimateOf(row),
  );
}

/// [row]'s estimate. Rows from before estimates were kept apart from the
/// factor in use were all estimates.
double? _estimateOf(GymExerciseMultiplier row) =>
    row.estimate ?? (row.manual ? null : row.multiplier);

GymExerciseMultiplier? _rowOf(
  List<GymExerciseMultiplier> rows,
  int exerciseId,
) {
  for (final row in rows) {
    if (row.exerciseId == exerciseId) return row;
  }
  return null;
}

/// The factors analytics bring weights home with: for each gym, every
/// machine or cable exercise of [exercises] at its factor. Plates and
/// dumbbells weigh the same everywhere, so they are left out.
Map<int, Map<int, double>> machineFactors(
  List<Gym> gyms,
  List<Exercise> exercises,
) {
  final machines = [
    for (final exercise in exercises)
      if (convertsAcrossGyms(exercise.equipment)) exercise.id,
  ];
  return {
    for (final gym in gyms)
      if (!gym.isPrimary)
        gym.id: {for (final id in machines) id: gymFactorOf(gym, id).value},
  };
}

/// One machine's weights carried from the gym it was last done at to the
/// gym of this workout.
class GymConversion {
  const GymConversion({
    required this.from,
    required this.to,
    required this.fromFactor,
    required this.toFactor,
  });

  final Gym from;
  final Gym to;
  final GymFactor fromFactor;
  final GymFactor toFactor;

  /// Kilograms at [from] as kilograms at [to].
  double convert(double kilograms) =>
      kilograms * fromFactor.value / toFactor.value;

  /// Whether the conversion hangs on [to]'s factor; else on [from]'s, the
  /// workout being at home.
  bool get hangsOnTo => toFactor.source != FactorSource.home;

  /// The gym whose factor the conversion hangs on, and that factor.
  Gym get basisGym => hangsOnTo ? to : from;
  GymFactor get basis => hangsOnTo ? toFactor : fromFactor;

  /// [kilograms] at [from] as a likely range at [to], from how sure the
  /// factor is ([GymFactor.band]).
  ({double low, double high}) rangeOf(double kilograms) {
    final band = basis.band;
    double at(double delta) => hangsOnTo
        ? kilograms * fromFactor.value / (toFactor.value + delta)
        : kilograms * (fromFactor.value + delta) / toFactor.value;
    final a = at(-band);
    final b = at(band);
    return (low: math.min(a, b), high: math.max(a, b));
  }

  /// The factor [basisGym] gets when [fromKilograms] at [from] feels like
  /// [toKilograms] at [to].
  double factorFor({
    required double fromKilograms,
    required double toKilograms,
  }) => hangsOnTo
      ? fromKilograms * fromFactor.value / toKilograms
      : toKilograms * toFactor.value / fromKilograms;
}

/// How [exerciseId] done at [fromGymId] carries to [toGymId]; null when
/// it does not convert ([converts] false: plates, dumbbells, bodyweight),
/// at the same gym, or when either gym is unknown.
GymConversion? gymConversionOf({
  required bool converts,
  required List<Gym> gyms,
  required int exerciseId,
  required int? fromGymId,
  required int? toGymId,
}) {
  if (!converts || fromGymId == null || toGymId == null) return null;
  if (fromGymId == toGymId) return null;
  Gym? from;
  Gym? to;
  for (final gym in gyms) {
    if (gym.id == fromGymId) from = gym;
    if (gym.id == toGymId) to = gym;
  }
  if (from == null || to == null) return null;
  return GymConversion(
    from: from,
    to: to,
    fromFactor: gymFactorOf(from, exerciseId),
    toFactor: gymFactorOf(to, exerciseId),
  );
}

/// [kilograms] rounded to the nearest load a stack or plates make in
/// [unit]: 2.5 kg, or 5 lb.
double roundToLoad(double kilograms, WeightUnit unit) {
  final step = unit == WeightUnit.kilograms ? 2.5 : 5.0;
  final shown = unit.fromKilograms(kilograms);
  return unit.toKilograms((shown / step).round() * step);
}

/// [gym]'s factor rows worked out again from [sessions] for [exerciseIds]
/// (the machines and cables): a new estimate replaces an estimate, a factor
/// set by hand stays and only learns the new estimate, and an estimate with
/// no workouts left to come from goes. [effectiveReps] as in
/// [estimateExerciseFactor].
List<GymExerciseMultiplier> refreshedFactors(
  Gym gym,
  List<WorkoutSession> sessions, {
  required int homeGymId,
  required Iterable<int> exerciseIds,
  DateTime? now,
  bool effectiveReps = false,
}) {
  final ids = {
    ...exerciseIds,
    for (final row in gym.perExerciseMultipliers)
      if (row.manual) row.exerciseId,
  };
  final rows = <GymExerciseMultiplier>[];
  for (final id in ids) {
    final estimate = estimateExerciseFactor(
      sessions,
      exerciseId: id,
      homeGymId: homeGymId,
      gymId: gym.id,
      now: now,
      effectiveReps: effectiveReps,
    );
    final kept = _rowOf(gym.perExerciseMultipliers, id);
    if (kept != null && kept.manual) {
      rows.add(
        GymExerciseMultiplier(
          exerciseId: id,
          multiplier: kept.multiplier,
          manual: true,
          estimate: estimate?.factor,
          samples: estimate?.samples ?? 0,
          spread: estimate?.spread ?? 0,
        ),
      );
    } else if (estimate != null) {
      rows.add(
        GymExerciseMultiplier(
          exerciseId: id,
          multiplier: estimate.factor,
          estimate: estimate.factor,
          samples: estimate.samples,
          spread: estimate.spread,
        ),
      );
    }
  }
  return rows;
}

/// A gym's overall factor from its machines' estimates: their median; null
/// without any.
double? overallFactorOf(List<GymExerciseMultiplier> rows) {
  final estimates = [for (final row in rows) ?row.estimate];
  return estimates.isEmpty ? null : _median(estimates);
}

/// [rows] with [exerciseId]'s factor set by hand to [factor], its estimate
/// kept beside it.
List<GymExerciseMultiplier> withManualFactor(
  List<GymExerciseMultiplier> rows,
  int exerciseId,
  double factor,
) {
  final kept = _rowOf(rows, exerciseId);
  return [
    for (final row in rows)
      if (row.exerciseId != exerciseId) row,
    GymExerciseMultiplier(
      exerciseId: exerciseId,
      multiplier: factor,
      manual: true,
      estimate: kept == null ? null : _estimateOf(kept),
      samples: kept?.samples ?? 0,
      spread: kept?.spread ?? 0,
    ),
  ];
}

/// [rows] with [exerciseId] back on its estimate; without one, on the
/// gym's overall factor.
List<GymExerciseMultiplier> withoutManualFactor(
  List<GymExerciseMultiplier> rows,
  int exerciseId,
) {
  final kept = _rowOf(rows, exerciseId);
  final estimate = kept == null ? null : _estimateOf(kept);
  return [
    for (final row in rows)
      if (row.exerciseId != exerciseId) row,
    if (kept != null && estimate != null)
      GymExerciseMultiplier(
        exerciseId: exerciseId,
        multiplier: estimate,
        estimate: estimate,
        samples: kept.samples,
        spread: kept.spread,
      ),
  ];
}

/// [gyms] with [homeId] made the primary gym: every factor set by hand and
/// every overall factor measured against it instead, so a machine keeps
/// reading the same against the new home. Estimates are worked out again
/// afterwards ([refreshedFactors]).
List<Gym> rebasedOn(List<Gym> gyms, int homeId) {
  Gym? home;
  for (final gym in gyms) {
    if (gym.id == homeId) home = gym;
  }
  if (home == null || home.isPrimary) return gyms;
  // The new home's factors as they were, read before any gym changes.
  final homeFactors = {
    for (final row in home.perExerciseMultipliers) row.exerciseId: row,
  };
  final base = home.multiplier;
  double homeFactor(int exerciseId) =>
      homeFactors[exerciseId]?.multiplier ?? base;
  for (final gym in gyms) {
    if (gym.id == homeId) {
      gym
        ..isPrimary = true
        ..multiplier = 1.0;
      continue;
    }
    gym
      ..perExerciseMultipliers = [
        for (final row in gym.perExerciseMultipliers)
          if (row.manual)
            GymExerciseMultiplier(
              exerciseId: row.exerciseId,
              multiplier: row.multiplier / homeFactor(row.exerciseId),
              manual: true,
            )
          else
            row,
      ]
      ..multiplier = gym.isPrimary ? 1 / base : gym.multiplier / base
      ..isPrimary = false;
  }
  return gyms;
}

/// [setups] with [exerciseId]'s note set to [note]; an empty note removes
/// it.
List<GymMachineSetup> withSetupNote(
  List<GymMachineSetup> setups,
  int exerciseId,
  String note,
) {
  final trimmed = note.trim();
  return [
    for (final setup in setups)
      if (setup.exerciseId != exerciseId) setup,
    if (trimmed.isNotEmpty)
      GymMachineSetup(exerciseId: exerciseId, note: trimmed),
  ];
}

/// [gym]'s setup note for [exerciseId]; null without one.
String? setupNoteOf(Gym gym, int exerciseId) {
  for (final setup in gym.machineSetups) {
    if (setup.exerciseId == exerciseId) return setup.note;
  }
  return null;
}
