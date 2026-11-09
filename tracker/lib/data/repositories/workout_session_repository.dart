import 'package:isar_community/isar.dart';

import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/services/set_prefill.dart';
import 'package:tracker/domain/services/split_rotation.dart';

class WorkoutSessionRepository {
  WorkoutSessionRepository(this._isar);

  final Isar _isar;

  Future<List<WorkoutSession>> getAll() =>
      _isar.workoutSessions.where().sortByEndTime().findAll();

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

  Future<List<WorkoutSession>> getForDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return _isar.workoutSessions
        .filter()
        .startTimeBetween(start, end, includeUpper: false)
        .sortByStartTimeDesc()
        .findAll();
  }

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

  Future<int> countLoggingSessions(int exerciseId) async {
    final sessions = await _isar.workoutSessions
        .filter()
        .setsElement((set) => set.exerciseIdEqualTo(exerciseId))
        .findAll();
    return sessions.length;
  }

  /// The split day of every session started from one, newest first. Reads
  /// three properties only: no session sets are loaded.
  Future<List<SplitDayVisit>> getSplitVisits() async {
    QueryBuilder<WorkoutSession, WorkoutSession, QAfterSortBy> query() => _isar
        .workoutSessions
        .filter()
        .splitIdIsNotNull()
        .splitDayIndexIsNotNull()
        .sortByStartTimeDesc();
    final (splitIds, dayIndexes, startTimes) = await (
      query().splitIdProperty().findAll(),
      query().splitDayIndexProperty().findAll(),
      query().startTimeProperty().findAll(),
    ).wait;
    return [
      for (var i = 0; i < splitIds.length; i++)
        if (i < dayIndexes.length && i < startTimes.length)
          SplitDayVisit(
            splitId: splitIds[i]!,
            dayIndex: dayIndexes[i]!,
            startTime: startTimes[i],
          ),
    ];
  }

  /// [exerciseId]'s sets in the most recent session that logged it, or null
  /// when no session did.
  Future<PreviousPerformance?> getPreviousPerformance(int exerciseId) async {
    final session = await _isar.workoutSessions
        .filter()
        .setsElement((set) => set.exerciseIdEqualTo(exerciseId))
        .sortByStartTimeDesc()
        .findFirst();
    if (session == null) return null;
    final sets = [
      for (final set in session.sets)
        if (set.exerciseId == exerciseId) set,
    ]..sort((a, b) => a.order.compareTo(b.order));
    return PreviousPerformance(date: session.startTime, sets: sets);
  }

  Stream<List<WorkoutSession>> watchAll() => _isar.workoutSessions
      .where()
      .sortByStartTimeDesc()
      .watch(fireImmediately: true);

  /// Fires after every change to the sessions collection.
  Stream<void> watchChanges() => _isar.workoutSessions.watchLazy();

  /// Every session, newest first.
  List<WorkoutSession> getAllSync() =>
      _isar.workoutSessions.where().sortByStartTimeDesc().findAllSync();

  /// Start times of every session, newest first. A property query skips
  /// decoding titles and sets, so it is cheap enough to run inside a frame.
  List<DateTime> getStartTimesSync() => _isar.workoutSessions
      .where()
      .sortByStartTimeDesc()
      .startTimeProperty()
      .findAllSync();

  /// Sessions starting on [day]'s local calendar date, newest first.
  ///
  /// The query window is padded by a day on each side and the results are
  /// matched on their local date, so 23 h and 25 h DST days are exact.
  List<WorkoutSession> getOnLocalDaySync(DateTime day) {
    final sessions = _isar.workoutSessions
        .filter()
        .startTimeBetween(
          DateTime.utc(day.year, day.month, day.day - 1),
          DateTime.utc(day.year, day.month, day.day + 2),
        )
        .sortByStartTimeDesc()
        .findAllSync();
    return [
      for (final session in sessions)
        if (session.startTime.year == day.year &&
            session.startTime.month == day.month &&
            session.startTime.day == day.day)
          session,
    ];
  }
}
