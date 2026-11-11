import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/models/session_draft.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/services/session_changes.dart';

WorkoutSession _saved() => WorkoutSession(
  title: 'Push',
  startTime: DateTime(2026, 11, 9, 18, 4),
  endTime: DateTime(2026, 11, 9, 19, 16),
  gymId: 3,
  splitId: 7,
  splitDayIndex: 1,
  sets: [
    WorkoutSet(
      exerciseId: 1,
      weight: 40,
      reps: 10,
      type: SetType.warmup,
      order: 0,
    ),
    WorkoutSet(exerciseId: 1, weight: 80, reps: 8, order: 1, rpe: 8),
    WorkoutSet(exerciseId: 2, weight: 50, reps: 8, order: 2),
    WorkoutSet(exerciseId: 1, weight: 80, reps: 7, order: 3, rpe: 9),
  ],
)..id = 42;

void main() {
  group('SessionDraft', () {
    test('opens with every saved value and no changes', () {
      final saved = _saved();
      final draft = SessionDraft.of(saved);
      expect(draft.title, 'Push');
      expect(draft.gymId, 3);
      expect([for (final s in draft.sets) s.origin], [0, 1, 2, 3]);
      expect(sessionChangeCount(saved, draft), 0);
    });

    test('saving keeps what the page does not edit', () {
      final saved = _saved();
      final written = SessionDraft.of(saved)
          .copyWith(title: '  Pull  ')
          .applyTo(saved);
      expect(written.id, 42);
      expect(written.title, 'Pull');
      expect(written.splitId, 7);
      expect(written.splitDayIndex, 1);
      expect(written.gymId, 3);
      expect(written.endTime, saved.endTime);
      expect([for (final s in written.sets) s.rpe], [null, 8, null, 9]);
      expect([for (final s in written.sets) s.order], [0, 1, 2, 3]);
      expect(written.sets.first.isWarmup, isTrue);
    });

    test('adds a set after the exercise\'s last one, with its values', () {
      final draft = SessionDraft.of(_saved());
      expect(draft.addedSetIndex(1), 4);
      expect(draft.addedSetIndex(2), 3);
      final added = draft.addSet(2);
      expect([for (final s in added.sets) s.exerciseId], [1, 1, 2, 2, 1]);
      final set = added.sets[3];
      expect(set.isNew, isTrue);
      expect(set.weight, 50);
      expect(set.reps, 8);
      expect(set.warmup, isFalse);
      expect(set.rpe, isNull);
      expect(set.order, 4);
    });

    test('an exercise not in the workout gets its set at the end', () {
      final draft = SessionDraft.of(_saved());
      expect(draft.addedSetIndex(9), 4);
      final added = draft.addSet(9, weight: 20, reps: 12);
      expect(added.sets.last.exerciseId, 9);
      expect(added.sets.last.weight, 20);
      expect(added.sets.last.reps, 12);
    });

    test('clears a rating and can clear the end time', () {
      final draft = SessionDraft.of(_saved())
          .updateSet(1, (set) => set.copyWith(rpe: null))
          .copyWith(endTime: null);
      expect(draft.sets[1].rpe, isNull);
      expect(draft.endTime, isNull);
    });
  });

  group('sessionChangeCount', () {
    test('counts each field and each set once', () {
      final saved = _saved();
      final draft = SessionDraft.of(saved)
          .copyWith(
            title: 'Pull',
            gymId: null,
            startTime: DateTime(2026, 11, 9, 18),
          )
          .updateSet(1, (set) => set.copyWith(weight: 82.5, reps: 7))
          .removeSet(2)
          .addSet(1);
      // Name, gym, start, one edited set, one removed, one added.
      expect(sessionChangeCount(saved, draft), 6);
    });

    test('notices a rating and a set type, which the old check ignored', () {
      final saved = _saved();
      expect(
        sessionChangeCount(
          saved,
          SessionDraft.of(saved).updateSet(1, (set) => set.copyWith(rpe: 9)),
        ),
        1,
      );
      expect(
        sessionChangeCount(
          saved,
          SessionDraft.of(saved)
              .updateSet(0, (set) => set.copyWith(warmup: false)),
        ),
        1,
      );
    });

    test('an edit undone by hand is no change', () {
      final saved = _saved();
      final draft = SessionDraft.of(saved)
          .copyWith(title: 'Push ')
          .updateSet(1, (set) => set.copyWith(weight: 85))
          .updateSet(1, (set) => set.copyWith(weight: 80));
      expect(sessionChangeCount(saved, draft), 0);
    });

    test('a set is edited or new, never both', () {
      final saved = _saved();
      final draft = SessionDraft.of(saved)
          .updateSet(3, (set) => set.copyWith(reps: 8))
          .addSet(2);
      expect(isEditedSet(saved, draft.sets[4]), isTrue);
      expect(isEditedSet(saved, draft.sets[1]), isFalse);
      expect(isEditedSet(saved, draft.sets[3]), isFalse);
      expect(savedSetOf(saved, draft.sets[3]), isNull);
      expect(savedSetOf(saved, draft.sets[4])?.reps, 7);
    });
  });
}
