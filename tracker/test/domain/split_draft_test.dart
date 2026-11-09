import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/models/split_draft.dart';
import 'package:tracker/domain/models/workout_split.dart';

WorkoutSplit _saved() => WorkoutSplit(
  title: 'PPL',
  description: 'Three days',
  order: 2,
  splitDays: [
    WorkoutSplitDay(
      title: 'Push',
      exercises: [
        ExerciseItem(
          exerciseId: 1,
          sets: [
            PlannedSet(order: 0, minReps: 8, maxReps: 12),
            PlannedSet(order: 1, minReps: 6, maxReps: 6),
          ],
        ),
        ExerciseItem(exerciseId: 2, targetSets: 3, targetReps: 10),
        ExerciseItem(exerciseId: 3),
      ],
    ),
    WorkoutSplitDay(title: 'Pull'),
  ],
)..id = 5;

void main() {
  group('SplitDraft.fromSplit', () {
    test('remembers where days and exercises came from', () {
      final draft = SplitDraft.fromSplit(_saved());
      expect(draft.splitId, 5);
      expect(draft.days.map((d) => d.origin), [0, 1]);
      expect(draft.days.first.exercises.map((e) => e.origin), [0, 1, 2]);
    });

    test('reads degenerate ranges as fixed reps and seeds legacy items', () {
      final exercises = SplitDraft.fromSplit(
        _saved(),
        fallback: const SetTarget(5),
      ).days.first.exercises;
      expect(exercises[0].sets, const [SetTarget(8, 12), SetTarget(6)]);
      expect(exercises[1].sets, List.filled(3, const SetTarget(10)));
      expect(exercises[2].sets, const [SetTarget(5)]);
    });
  });

  test('a draft round-trips through JSON and survives junk', () {
    final draft = SplitDraft.fromSplit(_saved()).addDay('Legs');
    expect(SplitDraft.fromJson(draft.toJson()), draft);
    final junk = SplitDraft.fromJson({
      'splitId': 'x',
      'days': [
        'bad',
        {
          'title': 3,
          'exercises': [
            {
              'exerciseId': 1,
              'sets': [
                [0],
                ['x'],
                [8, 12],
                [9, 4],
              ],
            },
          ],
        },
      ],
    });
    expect(junk.splitId, 0);
    expect(junk.days.single.title, '');
    expect(junk.days.single.exercises.single.sets, const [
      SetTarget(8, 12),
      SetTarget(9),
    ]);
  });

  test('writeTo replaces the content and keeps id and order', () {
    final saved = _saved();
    SplitDraft.fromSplit(saved)
        .copyWith(title: 'Push Pull Legs')
        .updateDay(0, (day) => day.removeExercise(2))
        .reorderDay(1, 0)
        .writeTo(saved);
    expect(saved.id, 5);
    expect(saved.order, 2);
    expect(saved.title, 'Push Pull Legs');
    expect(saved.splitDays.map((d) => d.title), ['Pull', 'Push']);
    expect(saved.splitDays.map((d) => d.order), [0, 1]);
    final push = saved.splitDays[1];
    expect(push.exercises.map((e) => e.exerciseId), [1, 2]);
    expect(push.exercises[1].targetSets, 3);
    expect(push.exercises.first.sets.map((s) => (s.order, s.maxReps)), [
      (0, 12),
      (1, null),
    ]);
  });

  group('edits', () {
    final base = SplitDraft.fromSplit(_saved());

    test('sets copy the last target and keep at least one', () {
      final exercise = base.days.first.exercises.first;
      expect(exercise.addSet(const SetTarget(5)).sets.last, const SetTarget(6));
      expect(
        const ExerciseDraft(exerciseId: 9).addSet(const SetTarget(5)).sets,
        const [SetTarget(5)],
      );
      final one = exercise.removeSet(0);
      expect(one.sets, const [SetTarget(6)]);
      expect(one.removeSet(0), one);
      expect(
        exercise.withAllSets(const SetTarget(4, 6)).sets,
        List.filled(2, const SetTarget(4, 6)),
      );
    });

    test('restoring puts an item back among the kept ones', () {
      final day = base.days.first;
      final edited = day
          .removeExercise(1)
          .addExercise(7, const [SetTarget(10)])
          .restoreExercise(day, 1);
      expect(edited.exercises.map((e) => e.exerciseId), [1, 2, 3, 7]);
      expect(edited.restoreExercise(day, 1), edited);

      final days = base.removeDay(0).restoreDay(base, 0);
      expect(days.days.map((d) => d.title), ['Push', 'Pull']);
    });

    test('a drag marks the item dragged, which equality ignores', () {
      final dragged = base.reorderDay(1, 0);
      expect(dragged.days.map((d) => (d.title, d.reordered)), [
        ('Pull', true),
        ('Push', false),
      ]);
      expect(dragged.reorderDay(0, 1), base, reason: 'back in saved order');
      expect(base.reorderDay(1, 1), same(base), reason: 'dropped in place');
      expect(
        SplitDraft.fromJson(dragged.toJson()).days.first.reordered,
        isTrue,
      );

      final exercises = base.days.first.reorderExercise(2, 0).exercises;
      expect(exercises.map((e) => (e.exerciseId, e.reordered)), [
        (3, true),
        (1, false),
        (2, false),
      ]);
      expect(
        ExerciseDraft.fromJson(exercises.first.toJson()).reordered,
        isTrue,
      );
    });

    test('out-of-range edits change nothing', () {
      expect(base.removeDay(9), base);
      expect(base.reorderDay(9, 0), base);
      expect(base.updateDay(9, (day) => day.copyWith(title: 'x')), base);
    });
  });

  test('setsSummary reads uniform and mixed targets', () {
    expect(
      setsSummary(const [SetTarget(8, 12), SetTarget(8, 12)]),
      '2 sets of 8-12 reps',
    );
    expect(setsSummary(const [SetTarget(1)]), '1 set of 1 rep');
    expect(
      setsSummary(const [SetTarget(10), SetTarget(8, 12)]),
      '2 sets: 10, 8-12 reps',
    );
    expect(setsSummary(const []), 'No sets');
  });
}
