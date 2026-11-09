import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/models/split_draft.dart';
import 'package:tracker/domain/services/split_diff.dart';

const _names = {1: 'Bench Press', 2: 'Incline Press', 3: 'Cable Fly', 4: 'OHP'};

String _nameOf(int id) => _names[id] ?? 'Exercise $id';

const _base = SplitDraft(
  splitId: 1,
  title: 'PPL',
  days: [
    DayDraft(
      origin: 0,
      title: 'Push',
      exercises: [
        ExerciseDraft(
          exerciseId: 1,
          origin: 0,
          sets: [SetTarget(8, 12), SetTarget(8, 12), SetTarget(8, 12)],
        ),
        ExerciseDraft(exerciseId: 2, origin: 1, sets: [SetTarget(10)]),
        ExerciseDraft(exerciseId: 3, origin: 2, sets: [SetTarget(12, 15)]),
      ],
    ),
    DayDraft(origin: 1, title: 'Day 2'),
    DayDraft(origin: 2, title: 'Legs'),
  ],
);

List<(SplitChangeKind, String?, String, String?, String?, String?)> _rows(
  SplitDiff diff,
) => [
  for (final c in diff.changes)
    (c.kind, c.group, c.title, c.before, c.after, c.detail),
];

void main() {
  test('an untouched draft has no changes', () {
    final diff = diffSplit(_base, _base, nameOf: _nameOf);
    expect(diff.isEmpty, isTrue);
    expect(diff.changedDays, isEmpty);
  });

  test('every kind of change, worded with old and new values', () {
    final draft = _base
        .copyWith(title: 'Push Pull Legs')
        .updateDay(
          0,
          (day) => day
              .updateExercise(0, (e) => e.withSet(2, const SetTarget(6, 8)))
              .removeExercise(2)
              .addExercise(4, const [SetTarget(6, 8), SetTarget(6, 8)])
              .updateExercise(1, (e) => e.addSet(const SetTarget(10))),
        )
        .updateDay(1, (day) => day.copyWith(title: 'Pull'))
        .removeDay(2)
        .addDay('Arms');
    final diff = diffSplit(_base, draft, nameOf: _nameOf);
    expect(_rows(diff), [
      (
        SplitChangeKind.changed,
        null,
        'Renamed split',
        'PPL',
        'Push Pull Legs',
        null,
      ),
      (
        SplitChangeKind.removed,
        null,
        'Removed Legs',
        null,
        null,
        'It had 0 exercises',
      ),
      (
        SplitChangeKind.added,
        null,
        'Added Arms',
        null,
        null,
        '0 exercises, 3rd in the split',
      ),
      (
        SplitChangeKind.removed,
        'Push',
        'Removed Cable Fly',
        null,
        null,
        'It had 1 set of 12-15 reps',
      ),
      (
        SplitChangeKind.changed,
        'Push',
        'Bench Press, set 3',
        '8-12 reps',
        '6-8 reps',
        null,
      ),
      (
        SplitChangeKind.added,
        'Push',
        'Incline Press, added set 2',
        null,
        null,
        '10 reps',
      ),
      (
        SplitChangeKind.added,
        'Push',
        'Added OHP',
        null,
        null,
        '2 sets of 6-8 reps, 3rd in the day',
      ),
      (SplitChangeKind.changed, 'Pull', 'Renamed day', 'Day 2', 'Pull', null),
    ]);
    expect(diff.count, 8);
    expect(diff.newDays, {2});
    expect(diff.changedDays, {0, 1, 2});
    expect(diff.removedDays, [2]);
    expect(diff.removedExercises, {
      0: [2],
    });
    expect(diff.isNewExercise(0, 2), isTrue);
    expect(diff.isChangedSet(0, 0, 2), isTrue);
    expect(diff.isChangedSet(0, 0, 1), isFalse);
    expect(diff.isChangedSet(0, 1, 1), isTrue);
    expect(diff.isChangedSet(0, 2, 0), isTrue, reason: 'a new exercise');
  });

  test('a move is reported once, not for everything it shifts', () {
    final draft = _base.updateDay(0, (day) => day.reorderExercise(2, 0));
    final diff = diffSplit(_base, draft, nameOf: _nameOf);
    expect(_rows(diff), [
      (SplitChangeKind.moved, 'Push', 'Moved Cable Fly', '3rd', '1st', null),
    ]);
    expect(diff.isChangedExercise(0, 0), isTrue);
    expect(diff.isChangedExercise(0, 1), isFalse);

    final days = diffSplit(_base, _base.reorderDay(0, 2), nameOf: _nameOf);
    expect(_rows(days), [
      (SplitChangeKind.moved, null, 'Moved Push', '1st', '3rd', null),
    ]);
  });

  test('a drag reports the item dragged, never the neighbour it passed', () {
    // Legs dragged up past Day 2, or Day 2 dragged down past Legs: the same
    // order, reported as whichever was dragged.
    final up = diffSplit(_base, _base.reorderDay(2, 1), nameOf: _nameOf);
    expect(_rows(up), [
      (SplitChangeKind.moved, null, 'Moved Legs', '3rd', '2nd', null),
    ]);
    expect(up.changedDays, {1});
    final down = diffSplit(_base, _base.reorderDay(1, 2), nameOf: _nameOf);
    expect(_rows(down), [
      (SplitChangeKind.moved, null, 'Moved Day 2', '2nd', '3rd', null),
    ]);
    expect(down.changedDays, {2});

    final draft = _base.updateDay(0, (day) => day.reorderExercise(1, 0));
    final diff = diffSplit(_base, draft, nameOf: _nameOf);
    expect(_rows(diff), [
      (
        SplitChangeKind.moved,
        'Push',
        'Moved Incline Press',
        '2nd',
        '1st',
        null,
      ),
    ]);
    expect(diff.isChangedExercise(0, 0), isTrue);
    expect(diff.isChangedExercise(0, 1), isFalse);
  });

  test('after several drags, only the dragged items are reported', () {
    // One move (Push to the end) would also explain this order, but Push
    // was never dragged.
    final draft = _base.reorderDay(2, 0).reorderDay(2, 0);
    expect(draft.days.map((d) => d.title), ['Day 2', 'Legs', 'Push']);
    expect(_rows(diffSplit(_base, draft, nameOf: _nameOf)), [
      (SplitChangeKind.moved, null, 'Moved Day 2', '2nd', '1st', null),
      (SplitChangeKind.moved, null, 'Moved Legs', '3rd', '2nd', null),
    ]);
  });

  test('a move that keeps its position number says what it sits below', () {
    final draft = _base.updateDay(
      0,
      (day) => day.removeExercise(0).reorderExercise(0, 1),
    );
    expect(_rows(diffSplit(_base, draft, nameOf: _nameOf)), [
      (
        SplitChangeKind.removed,
        'Push',
        'Removed Bench Press',
        null,
        null,
        'It had 3 sets of 8-12 reps',
      ),
      (
        SplitChangeKind.moved,
        'Push',
        'Moved Incline Press',
        null,
        null,
        'Now below Cable Fly',
      ),
    ]);
  });

  test('a set made a warm-up is reported with its new type', () {
    final draft = _base.updateDay(
      0,
      (day) => day.updateExercise(
        0,
        (e) => e.withSet(0, const SetTarget.warmup(8, 12)),
      ),
    );
    final diff = diffSplit(_base, draft, nameOf: _nameOf);
    expect(_rows(diff), [
      (
        SplitChangeKind.changed,
        'Push',
        'Bench Press, set 1',
        '8-12 reps',
        '8-12 warm-up reps',
        null,
      ),
    ]);
    expect(diff.isChangedSet(0, 0, 0), isTrue);
  });

  test('a removed set is named with what it was', () {
    final draft = _base.updateDay(
      0,
      (day) => day.updateExercise(0, (e) => e.removeSet(2)),
    );
    expect(_rows(diffSplit(_base, draft, nameOf: _nameOf)), [
      (
        SplitChangeKind.removed,
        'Push',
        'Bench Press, removed set 3',
        null,
        null,
        'It was 8-12 reps',
      ),
    ]);
  });

  test('ordinal suffixes', () {
    expect([1, 2, 3, 4, 11, 12, 13, 21, 22, 101, 111].map(ordinal), [
      '1st',
      '2nd',
      '3rd',
      '4th',
      '11th',
      '12th',
      '13th',
      '21st',
      '22nd',
      '101st',
      '111th',
    ]);
  });
}
