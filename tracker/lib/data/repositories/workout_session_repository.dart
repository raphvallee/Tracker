import 'package:isar_community/isar.dart';

import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';

/// Pages and cubits talk to these repositories, never to [Isar] directly.
/// Each wraps the [Isar] collection query API for one entity.
class WorkoutSessionRepository {
  WorkoutSessionRepository(this._isar);

  final Isar _isar;

  Future<List<WorkoutSession>> getAll() =>
      _isar.workoutSessions.where().sortByEndTime().findAll();

  /// Returns completed sessions newest first, capped at [limit].
  Future<List<WorkoutSession>> getRecent({int limit = 5}) {
    if (limit < 1) {
      throw ArgumentError.value(limit, 'limit', 'must be at least 1');
    }
    return _isar.workoutSessions
        .where()
        .filter()
        .endTimeIsNotNull()
        .sortByEndTimeDesc()
        .limit(limit)
        .findAll();
  }

  /// Watches completed sessions newest first, capped at [limit].
  Stream<List<WorkoutSession>> watchRecent({int limit = 5}) {
    if (limit < 1) {
      throw ArgumentError.value(limit, 'limit', 'must be at least 1');
    }
    return _isar.workoutSessions
        .where()
        .filter()
        .endTimeIsNotNull()
        .sortByEndTimeDesc()
        .limit(limit)
        .watch(fireImmediately: true);
  }

  /// Returns sessions whose start date falls on [date], newest first.
  Future<List<WorkoutSession>> getForDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return _isar.workoutSessions
        .filter()
        .startTimeBetween(start, end, includeUpper: false)
        .sortByStartTimeDesc()
        .findAll();
  }

  /// Returns sessions whose start time is within the inclusive [start, end]
  /// range, newest first.
  Future<List<WorkoutSession>> getBetween(DateTime start, DateTime end) {
    if (end.isBefore(start)) {
      throw ArgumentError.value(end, 'end', 'must not be before start');
    }
    return _isar.workoutSessions
        .filter()
        .startTimeBetween(start, end)
        .sortByStartTimeDesc()
        .findAll();
  }

  Future<WorkoutSession?> getById(int id) => _isar.workoutSessions.get(id);

  Future<int> put(WorkoutSession session) =>
      _isar.writeTxn(() => _isar.workoutSessions.put(session));

  Future<bool> delete(int id) =>
      _isar.writeTxn(() => _isar.workoutSessions.delete(id));

  /// Number of sessions that logged at least one set of [exerciseId], used to
  /// guard exercise deletion.
  Future<int> countLoggingSessions(int exerciseId) async {
    final sessions = await _isar.workoutSessions
        .filter()
        .setsElement((set) => set.exerciseIdEqualTo(exerciseId))
        .findAll();
    return sessions.length;
  }

  Stream<List<WorkoutSession>> watchAll() => _isar.workoutSessions
      .where()
      .sortByStartTimeDesc()
      .watch(fireImmediately: true);
}
