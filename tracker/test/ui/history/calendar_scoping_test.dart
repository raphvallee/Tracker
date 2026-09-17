import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/data/repositories/workout_session_repository.dart';
import 'package:tracker/domain/models/workout_session_summary.dart';
import 'package:tracker/ui/history/view_models/calendar_view_model.dart';

void main() {
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
