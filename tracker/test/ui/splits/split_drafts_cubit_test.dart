import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/domain/models/split_draft.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/ui/splits/view_models/split_drafts_cubit.dart';

import '../../../testing/fakes/in_memory_storage.dart';

WorkoutSplit _saved() => WorkoutSplit(
  title: 'PPL',
  splitDays: [
    WorkoutSplitDay(
      title: 'Push',
      exercises: [
        ExerciseItem(
          exerciseId: 1,
          sets: [PlannedSet(minReps: 8, maxReps: 12)],
        ),
      ],
    ),
  ],
)..id = 3;

void main() {
  late SplitDraftsCubit cubit;

  setUp(() {
    HydratedBloc.storage = InMemoryStorage();
    cubit = SplitDraftsCubit();
  });

  tearDown(() => cubit.close());

  test('an edit starts a draft, and undoing it drops the draft', () {
    final saved = _saved();
    expect(cubit.draftOf(saved).title, 'PPL');

    cubit.edit(saved, (draft) => draft.copyWith(title: 'Push Pull Legs'));
    expect(cubit.state.entries[3]!.base.title, 'PPL');
    expect(cubit.draftOf(saved).title, 'Push Pull Legs');
    expect(cubit.baseOf(saved).title, 'PPL');

    cubit.edit(saved, (draft) => draft.copyWith(title: 'PPL'));
    expect(cubit.state.entries, isEmpty);
  });

  test('a draft survives an app restart', () {
    final saved = _saved();
    cubit.edit(
      saved,
      (draft) => draft.updateDay(
        0,
        (day) => day.updateExercise(
          0,
          (exercise) => exercise.withSet(0, const SetTarget(6, 8)),
        ),
      ),
    );

    final restored = SplitDraftsState.fromJson(cubit.state.toJson());
    final entry = restored.entries[3]!;
    expect(entry.base, cubit.state.entries[3]!.base);
    expect(entry.draft.days.single.exercises.single.sets, const [
      SetTarget(6, 8),
    ]);
  });

  test('the base stays the version editing started from', () {
    final saved = _saved();
    cubit.edit(saved, (draft) => draft.addDay('Pull'));
    // Even if the saved split changed meanwhile, the draft compares with
    // what it was made from.
    saved.title = 'Changed elsewhere';
    cubit.edit(saved, (draft) => draft.addDay('Legs'));
    expect(cubit.state.entries[3]!.base.title, 'PPL');
    expect(cubit.state.entries[3]!.draft.days.map((d) => d.title), [
      'Push',
      'Pull',
      'Legs',
    ]);
  });

  test('discard drops the draft; save without a repository does too', () async {
    final saved = _saved();
    cubit.edit(saved, (draft) => draft.addDay('Pull'));
    cubit.discard(3);
    expect(cubit.state.entries, isEmpty);

    cubit.edit(saved, (draft) => draft.addDay('Pull'));
    await cubit.save(3);
    expect(cubit.state.entries, isEmpty);
  });

  test('unknown or malformed payloads fall back to no drafts', () {
    expect(SplitDraftsState.fromJson({'v': 9}).entries, isEmpty);
    expect(
      SplitDraftsState.fromJson({
        'v': 1,
        'entries': [
          'bad',
          {'base': 1},
          {'base': {}, 'draft': 'x'},
        ],
      }).entries,
      isEmpty,
    );
  });
}
