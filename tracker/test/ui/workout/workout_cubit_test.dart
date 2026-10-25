// Unit tests for WorkoutState (lib/pages/workout/workout_cubit.dart) - pure
// JSON serialization, no Isar, no HydratedBloc. The WorkoutCubit flow (which
// writes to Isar / HydratedStorage) is an integration test:
// test/integration/workout_test.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

void main() {
  group('WorkoutState serialization', () {
    test('fromJson applies safe defaults to malformed values', () {
      final state = WorkoutState.fromJson({
        'isInProgress': true,
        'plan': [
          {'exerciseId': 'bad', 'name': null, 'order': null},
        ],
        'sets': [
          {
            'exerciseId': null,
            'weight': 'bad',
            'reps': null,
            'type': 'unknown',
          },
        ],
      });

      expect(state.isInProgress, isTrue);
      expect(state.plan.single.exerciseId, 0);
      expect(state.plan.single.name, '');
      expect(state.sets.single.weight, 0);
      expect(state.sets.single.reps, 0);
      expect(state.sets.single.isWarmup, isFalse);
      expect(() => state.sets.add(state.sets.single), throwsUnsupportedError);
    });

    test('states and nested values have structural equality', () {
      const set = ActiveSet(exerciseId: 1, exerciseName: 'Bench');
      const plan = PlanExercise(exerciseId: 1, name: 'Bench');
      final first = WorkoutState(isInProgress: true, plan: [plan], sets: [set]);
      final second = WorkoutState(
        isInProgress: true,
        plan: [plan],
        sets: [set],
      );
      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('copyWith can clear nullable fields', () {
      final state = WorkoutState(
        isInProgress: true,
        startTime: DateTime(2024),
        gymId: 1,
        gymName: 'Gym',
        planTitle: 'Plan',
      );
      final cleared = state.copyWith(
        startTime: null,
        gymId: null,
        gymName: null,
        planTitle: null,
      );
      expect(cleared.startTime, isNull);
      expect(cleared.gymId, isNull);
      expect(cleared.gymName, isNull);
      expect(cleared.planTitle, isNull);
    });

    test('malformed collection values are ignored safely', () {
      final state = WorkoutState.fromJson({
        'plan': [
          null,
          'bad',
          {'exerciseId': 2},
        ],
        'sets': [
          null,
          'bad',
          {'exerciseId': 2},
        ],
      });
      expect(state.plan, hasLength(1));
      expect(state.sets, hasLength(1));
    });

    test('plan exercises carry planned sets through hydration', () {
      final state = WorkoutState(
        isInProgress: true,
        planTitle: 'Push',
        plan: [
          PlanExercise(
            exerciseId: 1,
            name: 'Bench',
            order: 0,
            sets: [
              PlannedSet(order: 0, minReps: 10),
              PlannedSet(order: 1, minReps: 8, maxReps: 12),
            ],
          ),
        ],
      );
      final restored = WorkoutState.fromJson(state.toJson());
      expect(restored.plan.single.sets, hasLength(2));
      expect(restored.plan.single.sets[0].minReps, 10);
      expect(restored.plan.single.sets[0].maxReps, isNull);
      expect(restored.plan.single.sets[1].minReps, 8);
      expect(restored.plan.single.sets[1].maxReps, 12);
      expect(restored, state);
    });

    test('plan sets default to empty and tolerate malformed entries', () {
      final state = WorkoutState.fromJson({
        'plan': [
          {
            'exerciseId': 1,
            'name': 'Bench',
            'sets': [
              null,
              'bad',
              {'order': 0, 'minReps': 10},
            ],
          },
        ],
      });
      expect(state.plan.single.sets, hasLength(1));
      expect(state.plan.single.sets.single.minReps, 10);

      final legacy = PlanExercise.fromJson({'exerciseId': 1, 'name': 'Bench'});
      expect(legacy.sets, isEmpty);
    });
  });

  group('WorkoutState schema versioning', () {
    test('legacy payloads without a version read as v1', () {
      final state = WorkoutState.fromJson({'isInProgress': true, 'gymId': 3});
      expect(state.isInProgress, isTrue);
      expect(state.gymId, 3);
    });

    test('versioned payload round-trips with the v field', () {
      final state = WorkoutState(
        isInProgress: true,
        startTime: DateTime(2026, 9, 3, 10),
        gymId: 3,
        gymName: 'Gym',
        planTitle: 'Plan',
        sets: const [
          ActiveSet(exerciseId: 1, exerciseName: 'Bench', weight: 60, reps: 8),
        ],
      );
      final json = state.toJson();
      expect(json['v'], 2);
      final restored = WorkoutState.fromJson(json);
      expect(restored, state);
      expect(restored.startTime, state.startTime);
      expect(restored.sets.single.exerciseName, 'Bench');
    });

    test('unknown schema version falls back to a clean idle state', () {
      final state = WorkoutState.fromJson({
        'v': 99,
        'isInProgress': true,
        'sets': [const ActiveSet(exerciseId: 1, exerciseName: 'Bench')],
      });
      expect(state, WorkoutState.initial());
      expect(state.isInProgress, isFalse);
      expect(state.sets, isEmpty);
    });

    test('saveError is transient: state-visible, never serialized', () {
      final state = WorkoutState(isInProgress: true);
      final failed = state.copyWith(saveError: 'nope');
      expect(failed.saveError, 'nope');
      expect(failed, isNot(equals(state)));
      expect(failed.toJson().containsKey('saveError'), isFalse);
      expect(WorkoutState.fromJson(failed.toJson()).saveError, isNull);
      expect(failed.copyWith(saveError: null).saveError, isNull);
    });
  });

  group('WorkoutState restore snapshots', () {
    WorkoutState inProgress() => WorkoutState(
      isInProgress: true,
      startTime: DateTime(2026, 9, 3, 10),
      gymId: 3,
      gymName: 'Gym',
      planTitle: 'Push',
      plan: const [PlanExercise(exerciseId: 1, name: 'Bench', order: 0)],
      sets: const [
        ActiveSet(exerciseId: 1, exerciseName: 'Bench', weight: 60, reps: 8),
      ],
    );

    test('saved snapshot survives hydration and keeps its history id', () {
      final saved = WorkoutSnapshot.fromState(inProgress());
      final state = WorkoutState.initial().copyWith(
        savedSnapshot: saved,
        savedSessionId: 7,
      );

      expect(state.canRestoreSaved(), isTrue);

      final restored = WorkoutState.fromJson(state.toJson());
      expect(restored.savedSnapshot, saved);
      expect(restored.savedSessionId, 7);
      expect(restored.canRestoreSaved(), isTrue);
    });

    test('legacy v1 payloads restore without a saved snapshot', () {
      final state = WorkoutState.fromJson({'isInProgress': false});
      expect(state.savedSnapshot, isNull);
      expect(state.savedSessionId, isNull);
      expect(state.canRestoreSaved(), isFalse);
    });

    test('discarded snapshot is in-memory only (never hydrated)', () {
      final state = WorkoutState.initial().copyWith(
        discardedSnapshot: WorkoutSnapshot.fromState(inProgress()),
        discardedAt: DateTime.now(),
      );

      expect(state.canRestoreDiscarded(), isTrue);

      final json = state.toJson();
      expect(json.containsKey('discarded'), isFalse);
      expect(json.containsKey('discardedAt'), isFalse);
      final restored = WorkoutState.fromJson(json);
      expect(restored.discardedSnapshot, isNull);
      expect(restored.discardedAt, isNull);
      expect(restored.canRestoreDiscarded(), isFalse);
    });

    test('canRestoreDiscarded respects the 15 minute window', () {
      WorkoutState withDiscardAt(DateTime at) =>
          WorkoutState.initial().copyWith(
            discardedSnapshot: WorkoutSnapshot.fromState(inProgress()),
            discardedAt: at,
          );

      expect(
        withDiscardAt(DateTime.now().subtract(const Duration(minutes: 5)))
            .canRestoreDiscarded(),
        isTrue,
      );
      // Exactly at the window boundary is too late.
      expect(
        withDiscardAt(
          DateTime.now().subtract(WorkoutState.discardRestoreWindow),
        ).canRestoreDiscarded(),
        isFalse,
      );
      expect(
        withDiscardAt(DateTime.now().subtract(const Duration(minutes: 20)))
            .canRestoreDiscarded(),
        isFalse,
      );
    });

    test('an in-progress workout blocks restoring', () {
      final state = inProgress().copyWith(
        savedSnapshot: WorkoutSnapshot.fromState(inProgress()),
        savedSessionId: 7,
        discardedSnapshot: WorkoutSnapshot.fromState(inProgress()),
        discardedAt: DateTime.now(),
      );
      expect(state.canRestoreSaved(), isFalse);
      expect(state.canRestoreDiscarded(), isFalse);
    });

    test('copyWith can clear the restore slots', () {
      final state = WorkoutState.initial().copyWith(
        savedSnapshot: WorkoutSnapshot.fromState(inProgress()),
        savedSessionId: 7,
        discardedSnapshot: WorkoutSnapshot.fromState(inProgress()),
        discardedAt: DateTime(2026, 9, 3, 10),
      );
      final cleared = state.copyWith(
        savedSnapshot: null,
        savedSessionId: null,
        discardedSnapshot: null,
        discardedAt: null,
      );
      expect(cleared.savedSnapshot, isNull);
      expect(cleared.savedSessionId, isNull);
      expect(cleared.discardedSnapshot, isNull);
      expect(cleared.discardedAt, isNull);
      expect(cleared.canRestoreSaved(), isFalse);
      expect(cleared.canRestoreDiscarded(), isFalse);
    });

    test('snapshots have structural equality', () {
      final first = WorkoutSnapshot.fromState(inProgress());
      final second = WorkoutSnapshot.fromState(inProgress());
      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(
        first,
        isNot(
          equals(
            WorkoutSnapshot.fromState(inProgress().copyWith(sets: const [])),
          ),
        ),
      );
    });
  });
}
