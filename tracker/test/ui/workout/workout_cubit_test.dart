// No Isar: the cases that persist through Isar live one per file in
// workout_*_test.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

import '../../../testing/fakes/in_memory_storage.dart';

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
              PlannedSet(order: 0, minReps: 10, isWarmup: true),
              PlannedSet(order: 1, minReps: 8, maxReps: 12),
            ],
          ),
        ],
      );
      final restored = WorkoutState.fromJson(state.toJson());
      expect(restored.plan.single.sets, hasLength(2));
      expect(restored.plan.single.sets[0].minReps, 10);
      expect(restored.plan.single.sets[0].maxReps, isNull);
      expect(restored.plan.single.sets[0].isWarmup, isTrue);
      expect(restored.plan.single.sets[1].minReps, 8);
      expect(restored.plan.single.sets[1].maxReps, 12);
      expect(restored.plan.single.sets[1].isWarmup, isFalse);
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
      expect(json['v'], 4);
      final restored = WorkoutState.fromJson(json);
      expect(restored, state);
      expect(restored.startTime, state.startTime);
      expect(restored.sets.single.exerciseName, 'Bench');
    });

    test('v4 carries the split link, the next gym and the last set time', () {
      final state = WorkoutState(
        isInProgress: true,
        startTime: DateTime(2026, 9, 3, 10),
        planTitle: 'Push Day',
        splitTitle: 'PPL',
        splitId: 4,
        splitDayIndex: 2,
        nextGymId: 9,
        lastSetAt: DateTime(2026, 9, 3, 10, 12),
      );
      final restored = WorkoutState.fromJson(state.toJson());
      expect(restored, state);
      expect(restored.splitTitle, 'PPL');
      expect(restored.splitId, 4);
      expect(restored.splitDayIndex, 2);
      expect(restored.nextGymId, 9);
      expect(restored.lastSetAt, DateTime(2026, 9, 3, 10, 12));
    });

    test('v3 payloads keep the split link and drop the last gym used', () {
      final state = WorkoutState.fromJson({
        'v': 3,
        'isInProgress': true,
        'splitTitle': 'PPL',
        'splitId': 4,
        'splitDayIndex': 1,
        'lastGymId': 9,
      });
      expect(state.splitTitle, 'PPL');
      expect(state.splitId, 4);
      expect(state.splitDayIndex, 1);
      expect(state.nextGymId, isNull, reason: 'workouts start at home');
    });

    test('v2 payloads restore with no split link', () {
      final state = WorkoutState.fromJson({
        'v': 2,
        'isInProgress': true,
        'planTitle': 'PPL · Push',
        'splitId': 4,
        'lastGymId': 9,
      });
      expect(state.planTitle, 'PPL · Push');
      expect(state.splitId, isNull);
    });

    test('malformed v4 fields fall back to null', () {
      final state = WorkoutState.fromJson({
        'v': 4,
        'splitTitle': 3,
        'splitId': 'x',
        'splitDayIndex': Object(),
        'nextGymId': 'y',
        'lastSetAt': 'not a date',
      });
      expect(state.splitTitle, isNull);
      expect(state.splitId, isNull);
      expect(state.splitDayIndex, isNull);
      expect(state.nextGymId, isNull);
      expect(state.lastSetAt, isNull);
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

  group('WorkoutCubit without a repository', () {
    late WorkoutCubit cubit;

    setUp(() {
      HydratedBloc.storage = InMemoryStorage();
      cubit = WorkoutCubit();
    });

    tearDown(() => cubit.close());

    test('ignores ending an idle workout', () async {
      await cubit.endWorkout();

      expect(cubit.state.isInProgress, isFalse);
      expect(cubit.state.savedSnapshot, isNull);
    });

    test('a set keeps its rating through updates, removal and hydration', () {
      cubit.startWorkout();
      cubit.logSet(exerciseId: 1, exerciseName: 'A', weight: 10, reps: 5);
      cubit.logSet(
        exerciseId: 1,
        exerciseName: 'A',
        weight: 20,
        reps: 5,
        rpe: 8,
      );
      expect(cubit.state.sets.map((s) => s.rpe), [null, 8]);

      cubit.updateSet(1, weight: 22.5, type: SetType.warmup);
      expect(cubit.state.sets.last.rpe, 8, reason: 'kept by other edits');
      cubit.setRpe(0, 9.5);
      cubit.removeSet(1);
      expect(cubit.state.sets.single.rpe, 9.5);

      final restored = WorkoutState.fromJson(cubit.state.toJson());
      expect(restored.sets.single.rpe, 9.5);
      expect(restored, cubit.state);
      cubit.setRpe(0, null);
      expect(cubit.state.sets.single.rpe, isNull);
      expect(
        ActiveSet.fromJson({'exerciseId': 1, 'rpe': 'hard'}).rpe,
        isNull,
        reason: 'malformed',
      );
    });

    test('removeSet drops a set and reindexes order', () async {
      cubit.startWorkout();
      cubit.logSet(exerciseId: 1, exerciseName: 'A', weight: 10, reps: 5);
      cubit.logSet(exerciseId: 2, exerciseName: 'B', weight: 20, reps: 5);
      cubit.logSet(exerciseId: 3, exerciseName: 'C', weight: 30, reps: 5);

      cubit.removeSet(1);
      expect(cubit.state.sets, hasLength(2));
      expect(cubit.state.sets.map((s) => s.order).toList(), [0, 1]);
      expect(cubit.state.sets.first.exerciseName, 'A');
      expect(cubit.state.sets.last.exerciseName, 'C');
    });

    test('updateSet edits weight/reps in place, keeping type and order', () {
      cubit.startWorkout();
      cubit.logSet(exerciseId: 1, exerciseName: 'A', weight: 10, reps: 5);
      cubit.logSet(
        exerciseId: 2,
        exerciseName: 'B',
        weight: 20,
        reps: 5,
        type: SetType.warmup,
      );

      cubit.updateSet(1, weight: 22.5, reps: 6);

      final updated = cubit.state.sets.singleWhere((s) => s.order == 1);
      expect(updated.weight, 22.5);
      expect(updated.reps, 6);
      expect(updated.isWarmup, isTrue);
      expect(updated.exerciseId, 2);
      expect(cubit.state.sets, hasLength(2));
      cubit.updateSet(1, weight: 25);
      expect(cubit.state.sets.singleWhere((s) => s.order == 1).reps, 6);
    });

    test('updateSet can flip the set type alone', () {
      cubit.startWorkout();
      cubit.logSet(exerciseId: 1, exerciseName: 'A', weight: 10, reps: 5);

      cubit.updateSet(0, type: SetType.warmup);

      final updated = cubit.state.sets.single;
      expect(updated.isWarmup, isTrue);
      expect(updated.weight, 10);
      expect(updated.reps, 5);
    });

    test('addExercise appends a card once per exercise', () {
      cubit.startWorkout();

      expect(cubit.addExercise(exerciseId: 1, name: 'Bench Press'), isTrue);
      expect(cubit.addExercise(exerciseId: 2, name: 'Squat'), isTrue);
      expect(cubit.addExercise(exerciseId: 1, name: 'Bench Press'), isFalse);

      expect(cubit.state.planTitle, isNull);
      expect(cubit.state.plan.map((e) => (e.exerciseId, e.order)).toList(), [
        (1, 0),
        (2, 1),
      ]);
    });

    test('addExercise skips an exercise that already has sets', () {
      cubit.startWorkout();
      cubit.logSet(exerciseId: 3, exerciseName: 'Row', weight: 50, reps: 8);

      expect(cubit.addExercise(exerciseId: 3, name: 'Row'), isFalse);
      expect(cubit.state.plan, isEmpty);
    });

    test('removeExercise drops its card and sets and reindexes both', () {
      cubit.startWorkout();
      cubit.addExercise(exerciseId: 1, name: 'A');
      cubit.addExercise(exerciseId: 2, name: 'B');
      cubit.addExercise(exerciseId: 3, name: 'C');
      cubit.logSet(exerciseId: 1, exerciseName: 'A', weight: 10, reps: 5);
      cubit.logSet(exerciseId: 2, exerciseName: 'B', weight: 20, reps: 5);
      cubit.logSet(exerciseId: 3, exerciseName: 'C', weight: 30, reps: 5);
      cubit.logSet(exerciseId: 2, exerciseName: 'B', weight: 25, reps: 5);

      cubit.removeExercise(2);

      expect(cubit.state.plan.map((e) => (e.exerciseId, e.order)).toList(), [
        (1, 0),
        (3, 1),
      ]);
      expect(cubit.state.sets.map((s) => (s.exerciseId, s.order)).toList(), [
        (1, 0),
        (3, 1),
      ]);
    });

    test('free workout cards survive hydration', () {
      cubit.startWorkout();
      cubit.addExercise(exerciseId: 1, name: 'Bench Press');

      final restored = WorkoutState.fromJson(cubit.state.toJson());
      expect(restored.planTitle, isNull);
      expect(restored.plan.single.name, 'Bench Press');
    });

    test('a plan workout keeps its split link through a restore', () async {
      cubit.startPlanWorkout(
        title: 'Push Day',
        splitTitle: 'PPL',
        splitId: 4,
        splitDayIndex: 0,
        exercises: const [PlanExercise(exerciseId: 1, name: 'Bench Press')],
      );
      cubit.logSet(exerciseId: 1, exerciseName: 'Bench', weight: 60, reps: 8);
      await cubit.discardWorkout();
      expect(cubit.state.splitId, isNull);
      expect(cubit.state.discardedSnapshot!.splitId, 4);

      cubit.restoreDiscardedWorkout();
      expect(cubit.state.planTitle, 'Push Day');
      expect(cubit.state.splitTitle, 'PPL');
      expect(cubit.state.splitId, 4);
      expect(cubit.state.splitDayIndex, 0);
    });

    test('a free workout clears the split link', () {
      cubit.startPlanWorkout(
        title: 'Push Day',
        splitId: 4,
        splitDayIndex: 1,
        exercises: const [],
      );
      cubit.startWorkout();
      expect(cubit.state.splitId, isNull);
      expect(cubit.state.splitDayIndex, isNull);
      expect(cubit.state.splitTitle, isNull);
    });

    test('a gym picked for the next workout lasts that one workout', () async {
      final away = Gym(name: 'Away', order: 1)..id = 5;
      cubit.pickNextGym(away);
      expect(cubit.state.isInProgress, isFalse);
      expect(cubit.state.nextGymId, 5);

      cubit.startWorkout(gym: away);
      expect(cubit.state.gymName, 'Away');
      expect(cubit.state.nextGymId, isNull, reason: 'used up by the start');
      await cubit.discardWorkout();
      expect(cubit.state.nextGymId, isNull);
    });

    test('moving a running workout leaves the next one at home', () {
      final home = Gym(name: 'Home', isPrimary: true)..id = 3;
      final away = Gym(name: 'Away', order: 1)..id = 5;
      cubit.startWorkout(gym: home);
      cubit.setGym(away);
      expect(cubit.state.gymId, 5);
      expect(cubit.state.gymName, 'Away');
      expect(cubit.state.nextGymId, isNull);
    });

    test('logging a set starts the rest clock; a new workout resets it', () {
      cubit.startWorkout();
      expect(cubit.state.lastSetAt, isNull);
      cubit.logSet(exerciseId: 1, exerciseName: 'Squat', weight: 100, reps: 5);
      expect(cubit.state.lastSetAt, isNotNull);
      cubit.startWorkout();
      expect(cubit.state.lastSetAt, isNull);
    });

    test('reorderExercise moves a card and renumbers the plan', () {
      cubit.startWorkout();
      cubit.addExercise(exerciseId: 1, name: 'A');
      cubit.addExercise(exerciseId: 2, name: 'B');
      cubit.addExercise(exerciseId: 3, name: 'C');
      cubit.logSet(exerciseId: 2, exerciseName: 'B', weight: 10, reps: 5);

      cubit.reorderExercise(0, 2);
      expect(cubit.state.plan.map((e) => e.name), ['B', 'C', 'A']);
      expect(cubit.state.plan.map((e) => e.order), [0, 1, 2]);
      expect(cubit.state.sets.single.exerciseName, 'B');

      cubit.reorderExercise(2, 0);
      expect(cubit.state.plan.map((e) => e.name), ['A', 'B', 'C']);
      cubit.reorderExercise(7, 0);
      expect(cubit.state.plan.map((e) => e.name), ['A', 'B', 'C']);
    });

    test('restore slots survive starting a later workout', () async {
      cubit.startWorkout();
      cubit.logSet(exerciseId: 1, exerciseName: 'A', weight: 10, reps: 5);
      await cubit.discardWorkout();
      final discarded = cubit.state.discardedSnapshot;

      cubit.startWorkout();
      expect(cubit.state.discardedSnapshot, discarded);
      expect(cubit.state.canRestoreDiscarded(), isFalse);

      await cubit.endWorkout();
      expect(cubit.state.isInProgress, isFalse);
      expect(cubit.state.canRestoreDiscarded(), isTrue);
    });
  });
}
