import 'dart:async';

import 'package:isar_community/isar.dart';
import 'package:tracker/domain/models/workout_session_summary.dart';

import 'package:tracker/domain/models/workout_session.dart';

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
    final local = date.toLocal();
    final start = DateTime(local.year, local.month, local.day);
    final end = DateTime(local.year, local.month, local.day + 1);
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

  /// A native single-property projection: no WorkoutSession/embedded set decode.
  Future<List<DateTime>> getStartTimes() async => List.unmodifiable(
    await _isar.workoutSessions.where().startTimeProperty().findAll(),
  );

  Stream<List<DateTime>> watchStartTimes() => _watchRefresh(getStartTimes);

  Future<List<WorkoutSessionSummary>> getSummariesForDate(
    DateTime date,
  ) async => List.unmodifiable(
    (await getForDate(date)).map(WorkoutSessionSummary.fromSession),
  );

  Stream<List<WorkoutSessionSummary>> watchSummariesForDate(DateTime date) =>
      _watchRefresh(() => getSummariesForDate(date));

  /// Listen before reading. One read at a time, with one pending refresh for
  /// any number of notifications during that read. Failed reads remain retryable
  /// on the next write (or by resubscribing); cancellation rejects late results.
  Stream<T> _watchRefresh<T>(Future<T> Function() read) {
    late StreamController<T> controller;
    StreamSubscription<void>? changes;
    var cancelled = false;
    var running = false;
    var dirty = false;

    Future<void> refresh() async {
      dirty = true;
      if (running || cancelled) return;
      running = true;
      try {
        while (dirty && !cancelled) {
          dirty = false;
          try {
            final value = await read();
            if (!cancelled) controller.add(value);
          } catch (error, stack) {
            if (!cancelled) controller.addError(error, stack);
          }
        }
      } finally {
        running = false;
      }
    }

    controller = StreamController<T>(
      onListen: () {
        try {
          changes = _isar.workoutSessions.watchLazy().listen(
            (_) => refresh(),
            onError: (Object error, StackTrace stack) {
              if (!cancelled) controller.addError(error, stack);
            },
          );
          unawaited(refresh());
        } catch (error, stack) {
          if (!cancelled) controller.addError(error, stack);
        }
      },
      onCancel: () async {
        cancelled = true;
        await changes?.cancel();
      },
    );
    return controller.stream;
  }

  Future<WorkoutSession?> getById(int id) => _isar.workoutSessions.get(id);

  Future<int> put(WorkoutSession session) =>
      _isar.writeTxn(() => _isar.workoutSessions.put(session));

  Future<bool> delete(int id) =>
      _isar.writeTxn(() => _isar.workoutSessions.delete(id));

  Stream<List<WorkoutSession>> watchAll() =>
      _isar.workoutSessions.where().watch(fireImmediately: true);
}
