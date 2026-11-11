import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/graph_config.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/services/analytics.dart';
import 'package:tracker/domain/services/graph_series.dart';

/// What the graphs are drawn from: every session, exercise and gym, read
/// once. Each graph's series is worked out once per range and day.
class AnalyticsData {
  AnalyticsData({
    this.sessions = const [],
    this.exercises = const [],
    this.gyms = const [],
  });

  static Future<AnalyticsData> load(TrackerRepository repo) async {
    final (sessions, exercises, gyms) = await (
      repo.sessions.getAll(),
      repo.exercises.getAll(),
      repo.gyms.getAll(),
    ).wait;
    return AnalyticsData(sessions: sessions, exercises: exercises, gyms: gyms);
  }

  final List<WorkoutSession> sessions;
  final List<Exercise> exercises;
  final List<Gym> gyms;

  late final Map<int, double> multipliers = {
    for (final gym in gyms) gym.id: gym.multiplier,
  };

  late final PerGymExerciseMultipliers exerciseMultipliers = {
    for (final gym in gyms)
      gym.id: {
        for (final value in gym.perExerciseMultipliers)
          value.exerciseId: value.multiplier,
      },
  };

  late final Map<int, String> gymNames = {
    for (final gym in gyms) gym.id: gym.name,
  };

  late final Map<int, String> _exerciseNames = {
    for (final exercise in exercises) exercise.id: exercise.title,
  };

  String exerciseName(int id) => _exerciseNames[id] ?? 'Exercise';

  WorkoutSession? session(int id) {
    for (final session in sessions) {
      if (session.id == id) return session;
    }
    return null;
  }

  final Map<(int?, GraphMetric, GraphTimeframe, DateTime), GraphSeries>
  _series = {};

  /// [metric] of [exerciseId] (every exercise when null) over [range] up
  /// to [now], worked out once per day.
  GraphSeries series({
    required int? exerciseId,
    required GraphMetric metric,
    required GraphTimeframe range,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    return _series[(
      exerciseId,
      metric,
      range,
      DateTime(at.year, at.month, at.day),
    )] ??= graphSeries(
      sessions: sessions,
      exerciseId: exerciseId,
      metric: metric,
      range: range,
      now: at,
      multipliers: multipliers,
      exerciseMultipliers: exerciseMultipliers,
    );
  }

  GraphSeries graph(GraphConfig config, GraphTimeframe range) => series(
    exerciseId: config.exerciseId,
    metric: config.metric,
    range: range,
  );
}
