// Workout integration tests (lib/pages/workout/). Two layers:
//  1. Cubit+repository: start → select gym → log working + warmup sets → end
//     workout → a WorkoutSession with the right gym/sets/duration lands in Isar,
//     plus hydration round-trips and the idle-guard.
//  2. Widget: the CurrentWorkout page renders the plan and logs a set inline.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:isar_community/isar.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/test_helpers.dart';

void main() {
  setUpAll(initIsarCore);

  setUp(() {
    // In-memory storage: the real HydratedStorage does file I/O behind a
    // static lock that deadlocks the widget-test fake-async zone once the
    // app shell (HydratedCubits) is pumped - same setup as app_test.
    HydratedBloc.storage = InMemoryStorage();
  });

  test('WorkoutCubit ignores ending an idle workout', () async {
    final cubit = WorkoutCubit();
    addTearDown(cubit.close);

    await cubit.endWorkout();

    expect(cubit.state.isInProgress, isFalse);
    expect(cubit.state.sets, isEmpty);
  });

  test('discardWorkout clears state without persisting a session', () async {
    final isar = await openTestIsar([
      WorkoutSessionSchema,
      GymSchema,
    ], name: 'workout_test_discard');
    final repo = TrackerRepository(isar);
    final cubit = WorkoutCubit(repository: repo);
    addTearDown(cubit.close);
    addTearDown(isar.close);

    cubit.startWorkout();
    cubit.logSet(exerciseId: 1, exerciseName: 'Squat', weight: 100, reps: 5);
    await cubit.discardWorkout();

    expect(cubit.state.isInProgress, isFalse);
    expect(cubit.state.sets, isEmpty);
    // The discarded session must never reach the history.
    expect(await repo.sessions.getAll(), isEmpty);
  });

  group('WorkoutCubit persistence', () {
    late Isar isar;
    late TrackerRepository repo;
    late WorkoutCubit cubit;

    setUp(() async {
      isar = await openTestIsar([
        WorkoutSessionSchema,
        GymSchema,
      ], name: 'workout_test_flow');
      repo = TrackerRepository(isar);
      cubit = WorkoutCubit(repository: repo);
    });

    tearDown(() async {
      await cubit.close();
      await isar.close();
    });

    test('start → log working + warmup → persist session to Isar', () async {
      final gymId = await repo.gyms.put(Gym(name: 'Home', isPrimary: true));
      final gym = (await repo.gyms.getById(gymId))!;

      cubit.startWorkout(gym: gym);
      expect(cubit.state.isInProgress, isTrue);
      expect(cubit.state.gymId, gymId);

      cubit.logSet(exerciseId: 1, exerciseName: 'Squat', weight: 100, reps: 5);
      cubit.logSet(
        exerciseId: 1,
        exerciseName: 'Squat',
        weight: 60,
        reps: 8,
        type: SetType.warmup,
      );
      cubit.logSet(exerciseId: 1, exerciseName: 'Squat', weight: 100, reps: 5);
      expect(cubit.state.sets, hasLength(3));
      expect(cubit.state.sets[1].isWarmup, isTrue);

      final started = DateTime.now();
      await cubit.endWorkout();

      expect(cubit.state.isInProgress, isFalse);
      final sessions = await repo.sessions.getAll();
      expect(sessions, hasLength(1));

      final session = sessions.first;
      expect(session.title, 'Home workout');
      expect(session.gymId, gymId);
      expect(session.sets, hasLength(3));
      expect(session.sets[1].type, SetType.warmup);
      // Duration computed from now − start and stored as endTime.
      expect(session.endTime, isNotNull);
      expect(
        session.endTime!.difference(session.startTime),
        isNot(greaterThan(const Duration(minutes: 1))),
        reason: 'duration should be ~(now - start) for a quick test session',
      );
      expect(started.difference(session.startTime).inSeconds, lessThan(60));
    });

    test(
      'failed save keeps the in-progress workout and surfaces an error',
      () async {
        final gymId = await repo.gyms.put(Gym(name: 'Home', isPrimary: true));
        final gym = (await repo.gyms.getById(gymId))!;

        cubit.startWorkout(gym: gym);
        cubit.logSet(
          exerciseId: 1,
          exerciseName: 'Squat',
          weight: 100,
          reps: 5,
        );
        expect(cubit.state.sets, hasLength(1));

        // Force the Isar write to fail by closing the instance out from under
        // the repository.
        await isar.close();
        await cubit.endWorkout();

        // Error-surfacing contract (PRODUCTION_READINESS.md Phase 1): the
        // in-progress workout must NOT be discarded from HydratedStorage.
        expect(cubit.state.isInProgress, isTrue);
        expect(cubit.state.sets, hasLength(1));
        expect(cubit.state.saveError, isNotNull);

        // Give the shared tearDown a live instance to close again.
        isar = await openTestIsar([
          WorkoutSessionSchema,
          GymSchema,
        ], name: 'workout_test_flow');
      },
    );

    test('startPlanWorkout sets the plan and planTitle on persist', () async {
      cubit.startPlanWorkout(
        title: 'PPL · Push',
        exercises: const [
          PlanExercise(exerciseId: 1, name: 'Bench Press', order: 0),
          PlanExercise(exerciseId: 2, name: 'OHP', order: 1),
        ],
      );
      expect(cubit.state.plan, hasLength(2));
      expect(cubit.state.planTitle, 'PPL · Push');
      expect(cubit.state.plan.first.name, 'Bench Press');

      cubit.logSet(
        exerciseId: 1,
        exerciseName: 'Bench Press',
        weight: 80,
        reps: 6,
      );
      await cubit.endWorkout();

      final session = (await repo.sessions.getAll()).single;
      expect(session.title, 'PPL · Push');
      expect(session.sets.single.exerciseId, 1);
    });

    test('removeSet drops a set and reindexes order', () async {
      cubit.startWorkout();
      cubit.logSet(exerciseId: 1, exerciseName: 'A', weight: 10, reps: 5);
      cubit.logSet(exerciseId: 2, exerciseName: 'B', weight: 20, reps: 5);
      cubit.logSet(exerciseId: 3, exerciseName: 'C', weight: 30, reps: 5);

      cubit.removeSet(1); // remove the middle set
      expect(cubit.state.sets, hasLength(2));
      expect(cubit.state.sets.map((s) => s.order).toList(), [0, 1]);
      expect(cubit.state.sets.first.exerciseName, 'A');
      expect(cubit.state.sets.last.exerciseName, 'C');
    });

    test('hydration round-trips plan + sets through JSON', () {
      cubit.startPlanWorkout(
        title: 'PPL · Pull',
        exercises: const [PlanExercise(exerciseId: 7, name: 'Row', order: 0)],
      );
      cubit.logSet(exerciseId: 7, exerciseName: 'Row', weight: 70, reps: 8);
      cubit.logSet(
        exerciseId: 7,
        exerciseName: 'Row',
        weight: 50,
        reps: 10,
        type: SetType.warmup,
      );

      final restored = WorkoutState.fromJson(cubit.state.toJson());
      expect(restored.isInProgress, isTrue);
      expect(restored.planTitle, 'PPL · Pull');
      expect(restored.plan.single.name, 'Row');
      expect(restored.sets, hasLength(2));
      expect(restored.sets[1].isWarmup, isTrue);
    });
  });

  group('CurrentWorkout logging UI', () {
    testWidgets('logs a set inline from a plan exercise', (tester) async {
      final cubit = await pumpApp(tester);
      cubit.startPlanWorkout(
        title: 'PPL · Push',
        exercises: const [
          PlanExercise(exerciseId: 1, name: 'Bench Press', order: 0),
        ],
      );

      // Switch to the CurrentWorkout tab (index 2) via the nav bar onChange -
      // hit-testing is brittle under the Offstage nested navigators.
      tester
          .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
          .onChange!(2);
      await tester.pumpAndSettle();

      // The plan title and exercise render.
      expect(find.text('PPL · Push'), findsOneWidget);
      expect(find.text('Bench Press'), findsOneWidget);
      // One inline add-form → weight + reps fields, warm-up checkbox, Add set.
      expect(find.byType(FTextField), findsNWidgets(2));
      final weightField = find
          .descendant(
            of: find.byType(FTextField).at(0),
            matching: find.byType(EditableText),
          )
          .first;
      final repsField = find
          .descendant(
            of: find.byType(FTextField).at(1),
            matching: find.byType(EditableText),
          )
          .first;

      await tester.enterText(weightField, '100');
      await tester.enterText(repsField, '5');

      // Mark the set as warm-up before adding (tap the checkbox itself -
      // FCheckbox's label is not part of the hit target).
      await tester.tap(find.byType(FCheckbox));
      await tester.pump();
      await tester.tap(find.text('Add set'));
      await tester.pumpAndSettle();

      final state = cubit.state;
      expect(state.sets, hasLength(1));
      expect(state.sets.single.weight, 100);
      expect(state.sets.single.reps, 5);
      expect(state.sets.single.type, SetType.warmup);
      expect(find.text('100 kg × 5'), findsOneWidget);
    });

    testWidgets('plan exercises show targets and pre-fill the next reps', (
      tester,
    ) async {
      final cubit = await pumpApp(tester);
      cubit.startPlanWorkout(
        title: 'PPL · Push',
        exercises: [
          PlanExercise(
            exerciseId: 1,
            name: 'Bench Press',
            order: 0,
            sets: [
              PlannedSet(order: 0, minReps: 10),
              PlannedSet(order: 1, minReps: 8, maxReps: 12),
            ],
          ),
        ],
      );

      tester
          .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
          .onChange!(2);
      await tester.pumpAndSettle();

      // The planned sets render as a summary line, and the reps field is
      // pre-filled with the first planned set's target.
      expect(find.text('Planned: 2 × 10, 8-12'), findsOneWidget);
      final repsField = find
          .descendant(
            of: find.byType(FTextField).at(1),
            matching: find.byType(EditableText),
          )
          .first;
      expect(tester.widget<EditableText>(repsField).controller.text, '10');

      // Logging the first planned set advances the pre-fill to the next
      // planned set's target (the range minimum).
      final weightField = find
          .descendant(
            of: find.byType(FTextField).at(0),
            matching: find.byType(EditableText),
          )
          .first;
      await tester.enterText(weightField, '100');
      await tester.tap(find.text('Add set'));
      await tester.pumpAndSettle();

      expect(find.text('100 kg × 10'), findsOneWidget);
      expect(tester.widget<EditableText>(repsField).controller.text, '8');
    });
  });
}
