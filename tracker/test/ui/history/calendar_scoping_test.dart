import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/data/repositories/workout_session_repository.dart';
import 'package:tracker/domain/models/workout_session_summary.dart';
import 'package:tracker/ui/history/view_models/calendar_view_model.dart';

void main() {
  test('equal projections retain derivations and suppress notifications', () {
    final repository = _Repository();
    final model = CalendarViewModel(initialDate: DateTime(2026, 3, 1));
    addTearDown(model.dispose);
    model.bindRepository(repository);
    model.setCalendarMode(true);
    var notifications = 0;
    model.addListener(() => notifications++);
    final march = DateTime(2026, 3, 31, 10);
    final april = DateTime(2026, 4, 1, 10);
    repository.dates.single.emit([march, march, april]);
    final index = model.dateIndex;
    final days = model.daysWithWorkouts;
    final grid = model.grid;
    expect(notifications, 1);
    repository.dates.single.emit([march, march, april]);
    repository.dates.single.emit([april, march, march]);
    repository.dates.single.emit([april, march, DateTime(2026, 3, 31, 20)]);
    expect(notifications, 1);
    expect(model.dateIndex, same(index));
    expect(model.daysWithWorkouts, same(days));
    expect(model.grid, same(grid));

    // Same total length, different counts, then remove the last March session.
    repository.dates.single.emit([march, april, april]);
    expect(notifications, 2);
    expect(model.dateIndex, isNot(same(index)));
    expect(model.dateIndex.countOn(DateTime(2026, 3, 31)), 1);
    expect(model.dateIndex.countOn(DateTime(2026, 4, 1)), 2);
    expect(model.dateIndex.monthWorkoutDays(2026, 3), 1);
    expect(model.dateIndex.monthWorkoutDays(2026, 4), 1);
    repository.dates.single.emit([april, april]);
    expect(notifications, 3);
    expect(model.dateIndex.countOn(DateTime(2026, 3, 31)), 0);
    expect(model.dateIndex.monthWorkoutDays(2026, 3), 0);
    expect(model.daysWithWorkouts, isEmpty);
    expect(model.grid, same(grid));

    // Recovery is observable even when the successful payload is unchanged.
    repository.dates.single.fail();
    repository.dates.single.emit([april, april]);
    expect(notifications, 5);
    expect(model.datesError, isNull);
    final retained = model.dateIndex;
    model.setCalendarMode(false);
    model.setCalendarMode(true);
    repository.dates.last.emit([april, april]);
    expect(notifications, 6);
    expect(model.datesLoading, isFalse);
    expect(model.dateIndex, same(retained));

    // A count-preserving move to a new month changes both month occupancies.
    final may = DateTime(2026, 5, 1);
    repository.dates.last.emit([may, may]);
    expect(notifications, 7);
    expect(model.dateIndex, isNot(same(retained)));
    expect(model.dateIndex.monthWorkoutDays(2026, 4), 0);
    expect(model.dateIndex.monthWorkoutDays(2026, 5), 1);
    expect(model.dateIndex.countOn(DateTime(2026, 4, 1)), 0);
    expect(model.dateIndex.countOn(may), 2);
  });

  test('summary equality is ordered and independent from date counts', () {
    final repository = _Repository();
    final model = CalendarViewModel(initialDate: DateTime(2026, 3, 1));
    addTearDown(model.dispose);
    model.bindRepository(repository);
    model.setCalendarMode(true);
    repository.dates.single.emit([DateTime(2026, 3, 1)]);
    final index = model.dateIndex;
    var notifications = 0;
    model.addListener(() => notifications++);
    WorkoutSessionSummary row({
      int id = 1,
      String title = 'Workout',
      int count = 2,
      int? gym,
      int hour = 10,
    }) => WorkoutSessionSummary(
      id: id,
      title: title,
      startTime: DateTime(2026, 3, 1, hour),
      setCount: count,
      gymId: gym,
    );
    var previous = <WorkoutSessionSummary>[row()];
    repository.days.single.emit(previous);
    final original = model.dayRows;
    repository.days.single.emit([row()]);
    expect(model.dayRows, same(original));
    expect(notifications, 1);
    expect(row().hashCode, row().hashCode);
    for (final next in [
      [row(title: 'Renamed')],
      [row(title: 'Renamed', count: 3)],
      [row(title: 'Renamed', count: 3, gym: 7)],
      [row(title: 'Renamed', count: 3, gym: 7, hour: 11)],
      [row(id: 2, title: 'Renamed', count: 3, gym: 7, hour: 11)],
      [row(id: 2), row(id: 3)],
      [row(id: 3), row(id: 2)],
      [row(id: 3), row(id: 4)],
    ]) {
      final before = notifications;
      repository.days.single.emit(next);
      expect(notifications, before + 1);
      expect(model.dayRows, orderedEquals(next));
      expect(model.dateIndex, same(index));
      previous = next;
    }
    final before = notifications;
    repository.days.single.fail();
    repository.days.single.emit(previous);
    expect(notifications, before + 2);
    expect(model.dayError, isNull);
  });

  test(
    'day, mode, repository and disposal reject late data and errors',
    () async {
      final first = _Repository();
      final second = _Repository();
      final model = CalendarViewModel(initialDate: DateTime(2026, 3, 1));
      model.bindRepository(first);
      expect(first.dates, isEmpty);
      model.setCalendarMode(true);
      first.dates.single.emit([DateTime(2026, 3, 1)]);
      first.days.single.emit([_row('first')]);
      expect(model.dayRows.single.title, 'first');
      final index = model.dateIndex;
      model.selectDay(DateTime(2026, 3, 2));
      expect(first.days.first.cancelled, isTrue);
      expect(model.dayRows, isEmpty);
      first.days.first.emit([_row('obsolete')]);
      first.days.first.fail();
      expect(model.dayRows, isEmpty);
      expect(model.dayError, isNull);
      first.days.last.emit([_row('latest')]);
      expect(model.dayRows.single.title, 'latest');
      expect(() => model.dayRows.clear(), throwsUnsupportedError);
      final dayRequests = first.days.length;
      model.goMonth(1);
      expect(first.days.length, dayRequests);
      expect(first.days.last.cancelled, isTrue);
      expect(model.dateIndex, same(index));
      model.selectDay(DateTime(2026, 4, 2));
      model.setCalendarMode(false);
      expect(first.dates.single.cancelled, isTrue);
      expect(first.days.last.cancelled, isTrue);
      first.dates.single.emit([DateTime(2020)]);
      first.dates.single.fail();
      expect(model.dateIndex, same(index));
      expect(model.datesError, isNull);
      model.setCalendarMode(true);
      expect(first.dates.length, 2);
      model.bindRepository(second);
      expect(first.dates.last.cancelled, isTrue);
      first.dates.last.emit([DateTime(2020)]);
      first.dates.last.fail();
      first.days.last.emit([_row('wrong repository')]);
      first.days.last.fail();
      expect(model.dateIndex.workoutDays, isEmpty);
      expect(model.dayRows, isEmpty);
      expect(model.datesError, isNull);
      expect(model.dayError, isNull);
      second.dates.single.emit([DateTime(2026, 4, 2)]);
      second.days.single.emit([_row('new repository')]);
      expect(model.dayRows.single.title, 'new repository');
      expect(model.selectedDay, DateTime(2026, 4, 2));
      model.dispose();
      expect(second.dates.single.cancelled, isTrue);
      expect(second.days.single.cancelled, isTrue);
      second.dates.single.fail();
      second.days.single.emit([_row('disposed')]);
    },
  );

  test(
    'date and day failures retain retry paths without resetting navigation',
    () {
      final repository = _Repository();
      final model = CalendarViewModel(initialDate: DateTime(2026, 3, 1));
      addTearDown(model.dispose);
      model.bindRepository(repository);
      model.setCalendarMode(true);
      repository.dates.single.emit([DateTime(2026, 3, 1)]);
      final index = model.dateIndex;
      repository.dates.single.fail();
      repository.days.single.fail();
      expect(model.datesError, isStateError);
      expect(model.dayError, isStateError);
      expect(model.datesLoading, isFalse);
      expect(model.dayLoading, isFalse);
      expect(model.dateIndex, same(index));
      model.retryDates();
      model.retryDay();
      expect(model.datesLoading, isTrue);
      expect(model.dayLoading, isTrue);
      repository.dates.last.emit(const []);
      repository.days.last.emit(const []);
      expect(model.datesError, isNull);
      expect(model.dayError, isNull);
      expect(model.selectedDay, DateTime(2026, 3, 1));
    },
  );
}

WorkoutSessionSummary _row(String title) => WorkoutSessionSummary(
  id: 1,
  title: title,
  startTime: DateTime(2026, 3, 1),
  setCount: 2,
  gymId: null,
);

class _Repository extends Fake implements WorkoutSessionRepository {
  final dates = <_LateStream<List<DateTime>>>[];
  final days = <_LateStream<List<WorkoutSessionSummary>>>[];
  @override
  Stream<List<DateTime>> watchStartTimes() {
    final stream = _LateStream<List<DateTime>>();
    dates.add(stream);
    return stream;
  }

  @override
  Stream<List<WorkoutSessionSummary>> watchSummariesForDate(DateTime day) {
    final stream = _LateStream<List<WorkoutSessionSummary>>();
    days.add(stream);
    return stream;
  }
}

/// Deliberately delivers even after cancellation to exercise generation guards,
/// not just the standard Dart stream's own suppression of cancelled callbacks.
class _LateStream<T> extends Stream<T> {
  void Function(T)? _data;
  Function? _error;
  bool cancelled = false;
  void emit(T value) => _data!(value);
  void fail() => Function.apply(_error!, [StateError('late')]);
  @override
  StreamSubscription<T> listen(
    void Function(T)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    _data = onData;
    _error = onError;
    return _Subscription<T>(() => cancelled = true);
  }
}

class _Subscription<T> extends Fake implements StreamSubscription<T> {
  _Subscription(this.onCancel);
  final void Function() onCancel;
  @override
  Future<void> cancel() async => onCancel();
}
