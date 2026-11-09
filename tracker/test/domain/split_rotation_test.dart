import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/domain/services/split_rotation.dart';

WorkoutSplit _split(int id, List<String> days, {int order = 0}) => WorkoutSplit(
  title: 'Split $id',
  order: order,
  splitDays: [for (final day in days) WorkoutSplitDay(title: day)],
)..id = id;

SplitDayVisit _visit(int split, int day, int date) => SplitDayVisit(
  splitId: split,
  dayIndex: day,
  startTime: DateTime(2026, 3, date),
);

void main() {
  final ppl = _split(1, ['Push', 'Pull', 'Legs']);
  final upperLower = _split(2, ['Upper', 'Lower'], order: 1);

  group('upNext', () {
    test('a split never trained starts at its first day', () {
      final next = upNext([ppl, upperLower], const []);
      expect(next!.split, ppl);
      expect(next.dayIndex, 0);
      expect(next.lastDone, isEmpty);
    });

    test('follows the day after the last one trained, wrapping around', () {
      expect(upNext([ppl], [_visit(1, 0, 1)])!.dayIndex, 1);
      expect(upNext([ppl], [_visit(1, 0, 1), _visit(1, 1, 3)])!.dayIndex, 2);
      expect(
        upNext([ppl], [_visit(1, 2, 5), _visit(1, 1, 3)])!.dayIndex,
        0,
        reason: 'visits come in any order',
      );
    });

    test('trains from the most recently trained split by default', () {
      final next = upNext(
        [ppl, upperLower],
        [_visit(1, 0, 1), _visit(2, 0, 4)],
      );
      expect(next!.split, upperLower);
      expect(next.dayIndex, 1);
    });

    test('the current split wins over the most recent one', () {
      final next = upNext(
        [ppl, upperLower],
        [_visit(1, 0, 1), _visit(2, 0, 4)],
        currentSplitId: 1,
      );
      expect(next!.split, ppl);
      expect(next.dayIndex, 1);
    });

    test('a deleted current split falls back to the most recent one', () {
      final next = upNext([ppl], [_visit(1, 1, 2)], currentSplitId: 99);
      expect(next!.split, ppl);
      expect(next.dayIndex, 2);
    });

    test('a removed day still moves the rotation on', () {
      expect(upNext([ppl], [_visit(1, 5, 2)])!.dayIndex, 0);
    });

    test('no splits, or a split without days', () {
      expect(upNext(const [], [_visit(1, 0, 1)]), isNull);
      final empty = _split(3, const []);
      final next = upNext([empty], const []);
      expect(next!.dayIndex, isNull);
      expect(next.day, isNull);
    });

    test('lastDone keeps each day newest date', () {
      final next = upNext(
        [ppl],
        [_visit(1, 0, 1), _visit(1, 0, 8), _visit(1, 2, 3), _visit(2, 1, 9)],
      );
      expect(next!.lastDone, {
        0: DateTime(2026, 3, 8),
        2: DateTime(2026, 3, 3),
      });
    });
  });

  group('splitsByLastUsed', () {
    final a = _split(1, ['A']);
    final b = _split(2, ['B'], order: 1);
    final c = _split(3, ['C'], order: 2);
    final d = _split(4, ['D'], order: 3);
    List<int> ids(List<WorkoutSplit> splits) => [
      for (final split in splits) split.id,
    ];

    test('the current split leads, the rest follow their last use', () {
      final visits = [_visit(2, 0, 2), _visit(3, 0, 5)];
      expect(ids(splitsByLastUsed([a, b, c, d], visits, currentSplitId: 1)), [
        1,
        3,
        2,
        4,
      ]);
      expect(ids(splitsByLastUsed([a, b, c, d], visits)), [
        3,
        2,
        1,
        4,
      ], reason: 'no choice: the most recently trained leads');
    });

    test('the split replaced as current lists right below the new one', () {
      // a was current until d replaced it on the 6th.
      final visits = [_visit(1, 0, 5), _visit(3, 0, 2)];
      expect(
        ids(
          splitsByLastUsed(
            [a, b, c, d],
            visits,
            currentSplitId: 4,
            usedAt: {1: DateTime(2026, 3, 6)},
          ),
        ),
        [4, 1, 3, 2],
      );
    });

    test('splits never used come last, in saved order', () {
      expect(ids(splitsByLastUsed([a, b, c, d], const [])), [1, 2, 3, 4]);
      expect(ids(splitsByLastUsed([a, b, c, d], const [], currentSplitId: 3)), [
        3,
        1,
        2,
        4,
      ]);
      expect(splitsByLastUsed(const [], const []), isEmpty);
    });
  });

  test('lastTrainedBySplit keeps the newest visit of each split', () {
    expect(
      lastTrainedBySplit([_visit(1, 0, 1), _visit(2, 0, 5), _visit(1, 1, 3)]),
      {1: DateTime(2026, 3, 3), 2: DateTime(2026, 3, 5)},
    );
  });

  test('currentSplitOf picks the first split when none was trained', () {
    expect(currentSplitOf([upperLower, ppl], const []), upperLower);
    expect(currentSplitOf(const [], const []), isNull);
  });
}
