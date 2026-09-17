import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:tracker/data/repositories/workout_session_repository.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_session_summary.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/ui/history/view_models/calendar_view_model.dart';

import '../../testing/test_helpers.dart';

void main() {
  late Isar isar;
  late WorkoutSessionRepository repository;
  setUpAll(() async {
    await initIsarCore();
    isar = await openTestIsar([
      WorkoutSessionSchema,
    ], name: 'calendar_repository');
  });
  tearDownAll(() => isar.close());
  setUp(() async {
    await isar.writeTxn(() => isar.clear());
    repository = WorkoutSessionRepository(isar);
  });

  test(
    'suspended calendar makes no reads on writes and resumes each source once',
    () async {
      final probe = _HistoryReadProbe(isar);
      final day = DateTime(2026, 3, 8);
      final model = CalendarViewModel(initialDate: day);
      addTearDown(model.dispose);
      model.bindRepository(probe);
      model.setCalendarMode(true);
      await waitFor(() => !model.datesLoading && !model.dayLoading);
      expect(probe.dateReads, 1);
      expect(probe.dayReads, 1);
      final index = model.dateIndex;
      model.setHistoryActive(false);
      // A separate live watcher is a delivery barrier for each hidden write.
      var deliveries = 0;
      final observer = repository.watchStartTimes().listen((_) => deliveries++);
      addTearDown(observer.cancel);
      await waitFor(() => deliveries == 1);
      for (var i = 0; i < 3; i++) {
        final before = deliveries;
        await repository.put(
          WorkoutSession(title: 'Hidden $i', startTime: day),
        );
        await waitFor(() => deliveries > before);
      }
      expect(probe.dateReads, 1);
      expect(probe.dayReads, 1);
      expect(model.dateIndex, same(index));
      expect(model.dayRows, isEmpty);
      model.setHistoryActive(true);
      model.setHistoryActive(true);
      await waitFor(() => !model.datesLoading && !model.dayLoading);
      expect(probe.dateReads, 2);
      expect(probe.dayReads, 2);
      expect(model.dateIndex.countOn(day), 3);
      expect(model.dayRows.length, 3);
      expect(model.selectedDay, day);
      expect(probe.fullReads, 0);
    },
  );

  test(
    'weight-only committed write delivers snapshots without rebuilding',
    () async {
      final session = WorkoutSession(
        title: 'Workout',
        startTime: DateTime(2026, 3, 8, 10),
        sets: [WorkoutSet(exerciseId: 1, weight: 30, reps: 5, order: 0)],
      );
      await repository.put(session);
      final probe = _DeliveryProbe(isar);
      final model = CalendarViewModel(initialDate: DateTime(2026, 3, 8));
      addTearDown(model.dispose);
      model.bindRepository(probe);
      model.setCalendarMode(true);
      await waitFor(() => !model.datesLoading && !model.dayLoading);
      final index = model.dateIndex;
      final days = model.daysWithWorkouts;
      final rows = model.dayRows;
      var notifications = 0;
      model.addListener(() => notifications++);
      final datesBefore = probe.dateDeliveries;
      final rowsBefore = probe.rowDeliveries;
      session.sets.single.weight = 55;
      await isar.writeTxn(() => isar.workoutSessions.put(session));
      // Await actual deliveries, not silence or a guessed watcher delay.
      await waitFor(
        () =>
            probe.dateDeliveries > datesBefore &&
            probe.rowDeliveries > rowsBefore,
      );
      expect(notifications, 0);
      expect(model.dateIndex, same(index));
      expect(model.daysWithWorkouts, same(days));
      expect(model.dayRows, same(rows));
      session.title = 'Renamed';
      await repository.put(session);
      await waitFor(() => model.dayRows.single.title == 'Renamed');
      expect(notifications, 1);
      expect(model.dateIndex, same(index));
      expect(rows.single.title, 'Workout');
    },
  );

  test(
    'date projection watches committed insert, count-preserving move, delete',
    () async {
      final session = WorkoutSession(
        title: 'Large workout',
        startTime: DateTime(2026, 3, 8, 12),
        sets: List.generate(
          1000,
          (i) => WorkoutSet(exerciseId: 1, weight: 10, reps: 5, order: i),
        ),
      );
      await repository.put(session);
      final values = <List<DateTime>>[];
      final subscription = repository.watchStartTimes().listen(values.add);
      addTearDown(subscription.cancel);
      await waitFor(() => values.isNotEmpty);
      expect(values.last, [session.startTime]);
      expect(() => values.last.clear(), throwsUnsupportedError);
      final next = WorkoutSession(startTime: DateTime(2026, 3, 9));
      // Raw collection writes must be observed, not only repository writes.
      await isar.writeTxn(() => isar.workoutSessions.put(next));
      await waitFor(() => values.last.length == 2);
      session.startTime = DateTime(2026, 4, 1);
      await repository.put(session);
      await waitFor(() => values.last.contains(session.startTime));
      expect(values.last, hasLength(2));
      expect(values.last, isNot(contains(DateTime(2026, 3, 8, 12))));
      await repository.delete(next.id);
      await waitFor(() => values.last.length == 1);
      expect(values.last.single, session.startTime);
      await expectLater(
        isar.writeTxn(() async {
          await isar.workoutSessions.clear();
          throw StateError('rollback');
        }),
        throwsStateError,
      );
      expect(await repository.getStartTimes(), [session.startTime]);
    },
  );

  test(
    'scoped rows have immutable metadata, descending order, half-open dates',
    () async {
      final day = DateTime(2026, 3, 8);
      final end = DateTime(2026, 3, 9);
      final first = WorkoutSession(
        title: 'First',
        startTime: day,
        gymId: 7,
        sets: [WorkoutSet(exerciseId: 1, weight: 30, reps: 5, order: 0)],
      );
      final last = WorkoutSession(
        title: 'Last',
        startTime: end.subtract(const Duration(microseconds: 1)),
      );
      for (final session in [first, last, WorkoutSession(startTime: end)]) {
        await repository.put(session);
      }
      final values = <List<WorkoutSessionSummary>>[];
      final subscription = repository
          .watchSummariesForDate(day)
          .listen(values.add);
      addTearDown(subscription.cancel);
      await waitFor(() => values.isNotEmpty);
      expect(values.last.map((row) => row.id), [last.id, first.id]);
      expect(values.last.last.title, 'First');
      expect(values.last.last.gymId, 7);
      expect(values.last.last.setCount, 1);
      expect(() => values.last.clear(), throwsUnsupportedError);
      first.title = 'Edited';
      first.sets = [];
      await repository.put(first);
      await waitFor(() => values.last.last.title == 'Edited');
      expect(values.last.last.setCount, 0);
      await repository.delete(last.id);
      await waitFor(() => values.last.length == 1);
    },
  );

  test('startup subscribes before read; burst refreshes serialize and coalesce', () async {
    final probe = _ProjectionProbe(isar)..hold = Completer<void>();
    final values = <List<DateTime>>[];
    final subscription = probe.watchStartTimes().listen(values.add);
    addTearDown(subscription.cancel);
    await waitFor(() => probe.reads == 1);
    for (var i = 1; i <= 5; i++) {
      await repository.put(WorkoutSession(startTime: DateTime(2026, 3, i)));
    }
    // Let all collection notifications arrive while the first snapshot is held.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(probe.reads, 1);
    probe.hold!.complete();
    await waitFor(() => values.isNotEmpty && values.last.length == 5);
    expect(probe.reads, 2);
    expect(probe.maximumConcurrent, 1);
    expect(probe.fullReads, 0);
  });

  test(
    'failed refresh recovers on write or resubscribe; cancellation drops work',
    () async {
      final probe = _ProjectionProbe(isar)..fail = true;
      final errors = <Object>[];
      final values = <List<DateTime>>[];
      var subscription = probe.watchStartTimes().listen(
        values.add,
        onError: errors.add,
      );
      await waitFor(() => errors.isNotEmpty);
      probe.fail = false;
      await repository.put(WorkoutSession(startTime: DateTime(2026, 3, 1)));
      await waitFor(() => values.isNotEmpty);
      await subscription.cancel();
      probe.hold = Completer<void>();
      values.clear();
      final initialReads = probe.reads;
      subscription = probe.watchStartTimes().listen(
        values.add,
        onError: errors.add,
      );
      await waitFor(() => probe.reads > initialReads);
      await repository.put(WorkoutSession(startTime: DateTime(2026, 3, 2)));
      await subscription.cancel();
      final readsAtCancel = probe.reads;
      probe.hold!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(values, isEmpty);
      expect(probe.reads, readsAtCancel);
      expect((await probe.watchStartTimes().first).length, 2);
    },
  );
}

class _HistoryReadProbe extends WorkoutSessionRepository {
  _HistoryReadProbe(super.isar);
  int dateReads = 0;
  int dayReads = 0;
  int fullReads = 0;
  @override
  Future<List<DateTime>> getStartTimes() {
    dateReads++;
    return super.getStartTimes();
  }

  @override
  Future<List<WorkoutSessionSummary>> getSummariesForDate(DateTime date) {
    dayReads++;
    return super.getSummariesForDate(date);
  }

  @override
  Future<List<WorkoutSession>> getAll() {
    fullReads++;
    return super.getAll();
  }
}

class _DeliveryProbe extends WorkoutSessionRepository {
  _DeliveryProbe(super.isar);
  int dateDeliveries = 0;
  int rowDeliveries = 0;

  @override
  Stream<List<DateTime>> watchStartTimes() =>
      super.watchStartTimes().map((dates) {
        dateDeliveries++;
        return dates;
      });

  @override
  Stream<List<WorkoutSessionSummary>> watchSummariesForDate(DateTime day) =>
      super.watchSummariesForDate(day).map((rows) {
        rowDeliveries++;
        return rows;
      });
}

/// Uses the real native date projection and real collection watcher, while
/// controlling completion to reproduce races without exposing a revision bus.
class _ProjectionProbe extends WorkoutSessionRepository {
  _ProjectionProbe(super.isar);
  int reads = 0;
  int concurrent = 0;
  int maximumConcurrent = 0;
  int fullReads = 0;
  bool fail = false;
  Completer<void>? hold;

  @override
  Future<List<DateTime>> getStartTimes() async {
    reads++;
    concurrent++;
    if (concurrent > maximumConcurrent) maximumConcurrent = concurrent;
    try {
      if (fail) throw StateError('read failed');
      final snapshot = await super.getStartTimes();
      await hold?.future;
      return snapshot;
    } finally {
      concurrent--;
    }
  }

  @override
  Future<List<WorkoutSession>> getAll() async {
    fullReads++;
    throw StateError('No full-history reads permitted');
  }
}
