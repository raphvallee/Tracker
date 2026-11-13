import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/services/fuzzy_search.dart';
import 'package:tracker/domain/services/history_filter.dart';

void main() {
  const names = {1: 'Bench Press', 2: 'Squat', 3: 'Incline Bench Press'};
  final now = DateTime(2026, 11, 12, 12);

  HistoryEntry entry({
    int id = 1,
    required DateTime start,
    int minutes = 60,
    List<int> exercises = const [1],
    int warmups = 0,
    int working = 3,
    int? splitId = 1,
    int? dayIndex = 0,
    int? gymId = 1,
    String title = 'Push',
  }) {
    final sets = <WorkoutSet>[
      for (final exercise in exercises) ...[
        for (var i = 0; i < warmups; i++)
          WorkoutSet(
            exerciseId: exercise,
            weight: 40,
            reps: 5,
            type: SetType.warmup,
          ),
        for (var i = 0; i < working; i++)
          WorkoutSet(exerciseId: exercise, weight: 80, reps: 8),
      ],
    ];
    final session = WorkoutSession(
      title: title,
      startTime: start,
      endTime: start.add(Duration(minutes: minutes)),
      gymId: gymId,
      sets: sets,
      splitId: splitId,
      splitDayIndex: dayIndex,
    )..id = id;
    return HistoryEntry.of(
      session,
      splitName: splitId == null ? null : 'Push Pull Legs',
      dayName: splitId == null ? null : title,
      gymName: 'Iron Temple',
      exerciseNames: names,
    );
  }

  group('HistoryEntry', () {
    test('counts working sets only and keeps its exercises', () {
      final e = entry(
        start: DateTime(2026, 11, 10, 18),
        exercises: [1, 2],
        warmups: 2,
        working: 3,
      );
      expect(e.workingSets, 6);
      expect(e.exerciseIds, [1, 2]);
      expect(e.minutes, 60);
      expect(e.words, containsAll(['push', 'pull', 'legs', 'iron', 'squat']));
    });
  });

  group('HistoryFilter', () {
    final tuesday = entry(start: DateTime(2026, 11, 10, 18), minutes: 75);
    final friday = entry(
      id: 2,
      start: DateTime(2026, 11, 6, 18),
      minutes: 40,
      exercises: [1, 2],
      working: 5,
      dayIndex: 2,
      gymId: 2,
      title: 'Legs',
    );
    final free = entry(
      id: 3,
      start: DateTime(2025, 12, 30, 9),
      splitId: null,
      dayIndex: null,
      title: 'Arms',
    );
    final all = [tuesday, friday, free];

    List<int> ids(HistoryFilter filter) => [
      for (final e in all)
        if (filter.matches(e, now)) e.id,
    ];

    test('an empty filter lets everything through', () {
      expect(HistoryFilter.none.isEmpty, isTrue);
      expect(ids(HistoryFilter.none), [1, 2, 3]);
    });

    test('splits, with null for workouts without one', () {
      expect(ids(const HistoryFilter(splitIds: {1})), [1, 2]);
      expect(ids(const HistoryFilter(splitIds: {null})), [3]);
    });

    test('split days', () {
      expect(ids(const HistoryFilter(days: {(splitId: 1, dayIndex: 2)})), [2]);
    });

    test('days of the week', () {
      expect(
        ids(const HistoryFilter(weekdays: {DateTime.tuesday, DateTime.friday})),
        [1, 2, 3],
      );
      expect(ids(const HistoryFilter(weekdays: {DateTime.friday})), [2]);
    });

    test('length, both ends included and either open', () {
      expect(ids(const HistoryFilter(minMinutes: 60)), [1, 3]);
      expect(ids(const HistoryFilter(maxMinutes: 40)), [2]);
      expect(ids(const HistoryFilter(minMinutes: 45, maxMinutes: 60)), [3]);
    });

    test('working sets', () {
      expect(ids(const HistoryFilter(minSets: 4)), [2]);
      expect(ids(const HistoryFilter(maxSets: 3)), [1, 3]);
    });

    test('date presets count back from today', () {
      expect(ids(const HistoryFilter(dates: HistoryDates.last30Days)), [1, 2]);
      expect(ids(const HistoryFilter(dates: HistoryDates.thisYear)), [1, 2]);
      expect(ids(const HistoryFilter(dates: HistoryDates.last3Months)), [1, 2]);
    });

    test('a picked range includes its last day', () {
      final filter = HistoryFilter(
        dates: HistoryDates.custom,
        from: DateTime(2026, 11, 6),
        to: DateTime(2026, 11, 10),
      );
      expect(ids(filter), [1, 2]);
      expect(
        ids(
          HistoryFilter(
            dates: HistoryDates.custom,
            from: DateTime(2026, 11, 6),
            to: DateTime(2026, 11, 6),
          ),
        ),
        [2],
      );
    });

    test('exercises must all be in the workout', () {
      expect(ids(const HistoryFilter(exerciseIds: {1})), [1, 2, 3]);
      expect(ids(const HistoryFilter(exerciseIds: {1, 2})), [2]);
    });

    test('gyms', () {
      expect(ids(const HistoryFilter(gymIds: {2})), [2]);
    });

    test('parts combine, and count toward the badge', () {
      const filter = HistoryFilter(
        splitIds: {1},
        weekdays: {DateTime.tuesday},
        minMinutes: 60,
      );
      expect(filter.activeCount, 3);
      expect(ids(filter), [1]);
    });

    test('copyWith clears an open end with null', () {
      const filter = HistoryFilter(minMinutes: 45, maxMinutes: 90);
      final cleared = filter.copyWith(minMinutes: null);
      expect(cleared.minMinutes, isNull);
      expect(cleared.maxMinutes, 90);
    });
  });

  group('searchHistory', () {
    final legs = entry(
      start: DateTime(2026, 11, 10),
      exercises: [2],
      title: 'Legs',
    );
    final push = entry(id: 2, start: DateTime(2026, 11, 9));

    test('a typo still finds the workout', () {
      final found = searchHistory(
        [legs, push],
        query: FuzzyQuery('sqaut'),
        filter: HistoryFilter.none,
        now: now,
      );
      expect(found, [legs]);
    });

    test('search and filters both apply', () {
      final found = searchHistory(
        [legs, push],
        query: FuzzyQuery('iron templ'),
        filter: const HistoryFilter(exerciseIds: {1}),
        now: now,
      );
      expect(found, [push]);
    });
  });

  group('nameQueryReadsAs', () {
    const all = ['Bench Press', 'Incline Bench Press', 'Squat', 'Push'];

    test('reads a typo as the shortest name it fits', () {
      expect(nameQueryReadsAs(FuzzyQuery('bech pres'), all), 'Bench Press');
      expect(nameQueryReadsAs(FuzzyQuery('sqaut'), all), 'Squat');
    });

    test('null when nothing or several names fit', () {
      expect(nameQueryReadsAs(FuzzyQuery('xyz'), all), isNull);
      expect(nameQueryReadsAs(FuzzyQuery('pu'), ['Push', 'Pull']), isNull);
    });
  });
}
