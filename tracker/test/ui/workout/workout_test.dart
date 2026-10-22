// Workout integration tests (lib/pages/workout/). Two layers:
//  1. Cubit+repository: start → select gym → log working + warmup sets → end
//     workout → a WorkoutSession with the right gym/sets/duration lands in Isar,
//     plus hydration round-trips and the idle-guard.
//  2. Widget: the CurrentWorkout page renders the plan and logs a set inline.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:isar_community/isar.dart';
import 'package:tracker/data/services/db.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/exercise.dart';
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

  group('reps storage widening (int → double)', () {
    test('legacy data migrates through DbInstance with intact reps', () async {
      // Fixture written by the pre-widening schema, where WorkoutSet.reps was
      // an int (see test/fixtures/reps_int_v1/): two sets with reps 5 and 8.
      final gz = File('test/fixtures/reps_int_v1/default.isar.gz')
          .readAsBytesSync();
      final dir = await Directory.systemTemp.createTemp('reps_migration');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/default.isar').writeAsBytesSync(GZipCodec().decode(gz));

      // DbInstance.getIsar uses path_provider for its directory; exercise the
      // same migration logic against this fixture directory instead.
      await DbInstance.migrateRepsToIntToDouble(dir.path);

      final isar = await Isar.open(
        [WorkoutSessionSchema, ExerciseSchema, GymSchema],
        directory: dir.path,
        name: 'default',
      );
      final repo = TrackerRepository(isar);

      final sessions = await repo.sessions.getAll();
      expect(sessions, hasLength(1));
      expect(sessions.single.title, 'Old session');
      // Whole-number int reps load as whole doubles - no zeroes, no rounding.
      expect(sessions.single.sets.map((s) => s.reps).toList(), [5.0, 8.0]);
      expect(sessions.single.sets.map((s) => s.weight).toList(), [100.0, 90.0]);
      expect(sessions.single.sets.last.isWarmup, isTrue);
      expect(sessions.single.sets.map((s) => s.order).toList(), [0, 1]);

      await isar.close();
    });
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

    test('fractional reps persist to Isar unchanged (no rounding)', () async {
      cubit.startWorkout();
      cubit.logSet(
        exerciseId: 1,
        exerciseName: 'Squat',
        weight: 100,
        reps: 3.5,
      );
      await cubit.endWorkout();

      final session = (await repo.sessions.getAll()).single;
      expect(session.sets.single.reps, 3.5);
      expect(session.sets.single.reps, isNot(4));
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

    test('saved workout can always be restored (leaving history)', () async {
      cubit.startWorkout();
      final originalStart = cubit.state.startTime;
      cubit.logSet(exerciseId: 1, exerciseName: 'Squat', weight: 100, reps: 5);
      await cubit.endWorkout();

      expect(cubit.state.isInProgress, isFalse);
      expect(cubit.state.canRestoreSaved, isTrue);
      expect(cubit.state.savedSessionId, isNotNull);

      await cubit.restoreSavedWorkout();

      // The saved session left history and is ongoing again, verbatim.
      expect(cubit.state.isInProgress, isTrue);
      expect(cubit.state.sets.single.weight, 100);
      expect(cubit.state.sets.single.reps, 5);
      expect(cubit.state.canRestoreSaved, isFalse);
      expect(await repo.sessions.getAll(), isEmpty);

      // Re-saving the restored session works and becomes the new restore
      // target - no duplicate entries from the restore round-trip, and the
      // original start time is replayed verbatim (not the restore time).
      await cubit.endWorkout();
      expect(cubit.state.isInProgress, isFalse);
      expect(cubit.state.canRestoreSaved, isTrue);
      final sessions = await repo.sessions.getAll();
      expect(sessions, hasLength(1));
      expect(sessions.single.sets, hasLength(1));
      expect(sessions.single.startTime, originalStart);
    });

    test('restored saved workout replays the split plan verbatim', () async {
      cubit.startPlanWorkout(
        title: 'PPL · Push',
        exercises: const [
          PlanExercise(exerciseId: 1, name: 'Bench Press', order: 0),
        ],
      );
      cubit.logSet(
        exerciseId: 1,
        exerciseName: 'Bench Press',
        weight: 80,
        reps: 6,
      );
      await cubit.endWorkout();

      await cubit.restoreSavedWorkout();

      expect(cubit.state.planTitle, 'PPL · Push');
      expect(cubit.state.plan.single.name, 'Bench Press');
      expect(cubit.state.plan.single.sets, isEmpty);
      expect(cubit.state.sets.single.exerciseName, 'Bench Press');
    });

    test('discarded workout is restorable only within 15 minutes', () async {
      var now = DateTime(2026, 9, 3, 10);
      final timed = WorkoutCubit(repository: repo, now: () => now);
      addTearDown(timed.close);

      timed.startWorkout();
      timed.logSet(exerciseId: 1, exerciseName: 'Squat', weight: 100, reps: 5);
      await timed.discardWorkout();

      // Never persisted, but held in memory for the window.
      expect(timed.state.isInProgress, isFalse);
      expect(timed.state.canRestoreDiscarded(now: now), isTrue);
      expect(timed.state.savedSnapshot, isNull);
      expect(await repo.sessions.getAll(), isEmpty);

      timed.restoreDiscardedWorkout();
      expect(timed.state.isInProgress, isTrue);
      expect(timed.state.sets.single.weight, 100);
      expect(timed.state.canRestoreDiscarded(now: now), isFalse);

      // Discard again and let the window lapse: restore becomes a no-op and
      // drops the stale snapshot.
      await timed.discardWorkout();
      now = now.add(const Duration(minutes: 16));
      expect(timed.state.canRestoreDiscarded(now: now), isFalse);
      timed.restoreDiscardedWorkout();
      expect(timed.state.isInProgress, isFalse);
      expect(timed.state.discardedSnapshot, isNull);
      expect(timed.state.discardedAt, isNull);
    });

    test('restore slots survive starting a later workout', () async {
      cubit.startWorkout();
      cubit.logSet(exerciseId: 1, exerciseName: 'A', weight: 10, reps: 5);
      await cubit.discardWorkout();
      final discarded = cubit.state.discardedSnapshot;

      cubit.startWorkout();
      expect(cubit.state.discardedSnapshot, discarded);
      // Restoring is blocked while the new session is in progress...
      expect(cubit.state.canRestoreDiscarded(), isFalse);

      // ...and offered again once it ends.
      await cubit.endWorkout();
      expect(cubit.state.isInProgress, isFalse);
      expect(cubit.state.canRestoreDiscarded(), isTrue);
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

    testWidgets('fractional reps log and persist exactly (two decimals)', (
      tester,
    ) async {
      final cubit = await pumpApp(tester);
      cubit.startPlanWorkout(
        title: 'PPL · Push',
        exercises: const [
          PlanExercise(exerciseId: 1, name: 'Bench Press', order: 0),
        ],
      );

      tester
          .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
          .onChange!(2);
      await tester.pumpAndSettle();

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

      // "3.25" logs as 3.25 - no rounding anywhere.
      await tester.enterText(weightField, '100');
      await tester.enterText(repsField, '3.25');
      await tester.tap(find.text('Add set'));
      await tester.pumpAndSettle();
      expect(cubit.state.sets, hasLength(1));
      expect(cubit.state.sets.single.reps, 3.25);
      expect(find.text('100 kg × 3.25'), findsOneWidget);

      // The live input formatter blocks a third decimal digit while typing.
      await tester.enterText(repsField, '3.255');
      expect(tester.widget<EditableText>(repsField).controller.text, '3.25');
      // A second decimal separator is ignored as well.
      await tester.enterText(repsField, '3.25.5');
      expect(tester.widget<EditableText>(repsField).controller.text, '3.25');

      // Hand-set values (bypassing the formatter, e.g. a paste through other
      // means) are truncated defensively to two decimals - never rounded.
      tester.widget<EditableText>(repsField).controller.text = '12.345';
      // Once two set tiles render, the button can sit below the test viewport;
      // press the FButton directly instead of hit-testing its label.
      FButton addSetButton() => tester.widget<FButton>(
        find.ancestor(of: find.text('Add set'), matching: find.byType(FButton)),
      );
      addSetButton().onPress!();
      await tester.pumpAndSettle();
      expect(cubit.state.sets, hasLength(2));
      expect(cubit.state.sets.last.reps, 12.34);
      expect(find.text('100 kg × 12.34'), findsOneWidget);

      // A fraction below one rep shows an explicit error, never a no-op.
      await tester.enterText(repsField, '0.4');
      addSetButton().onPress!();
      await tester.pumpAndSettle();
      expect(cubit.state.sets, hasLength(2));
      expect(find.text('Must be at least 1'), findsOneWidget);

      // A leading-decimal value is a fraction too, so it gets the same error
      // rather than being dropped without a message.
      await tester.enterText(repsField, '.5');
      addSetButton().onPress!();
      await tester.pumpAndSettle();
      expect(cubit.state.sets, hasLength(2));
      expect(find.text('Must be at least 1'), findsOneWidget);

      // Genuinely invalid input keeps the standard validation error.
      await tester.enterText(repsField, 'abc');
      addSetButton().onPress!();
      await tester.pumpAndSettle();
      expect(cubit.state.sets, hasLength(2));
      expect(find.text('Must be greater than 0'), findsOneWidget);
    });
  });

  group('CurrentWorkout restore buttons', () {
    Future<void> openWorkoutTab(WidgetTester tester) async {
      tester
          .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
          .onChange!(2);
      await tester.pumpAndSettle();
    }

    testWidgets('the last saved workout offers a restore button', (
      tester,
    ) async {
      final cubit = await pumpApp(tester);
      await openWorkoutTab(tester);

      // Nothing was saved yet - no restore offer.
      expect(find.text('Restore last workout'), findsNothing);

      cubit.startWorkout();
      cubit.logSet(exerciseId: 1, exerciseName: 'Squat', weight: 100, reps: 5);
      await cubit.endWorkout();
      await tester.pumpAndSettle();

      expect(find.text('Restore last workout'), findsOneWidget);

      // Restoring puts the session back in progress.
      await tester.tap(find.text('Restore last workout'));
      await tester.pumpAndSettle();
      expect(cubit.state.isInProgress, isTrue);
      expect(cubit.state.sets.single.weight, 100);
      expect(find.text('End Workout'), findsOneWidget);
      expect(find.text('Restore last workout'), findsNothing);
    });

    testWidgets('the last discarded workout offers a restore button', (
      tester,
    ) async {
      final cubit = await pumpApp(tester);
      await openWorkoutTab(tester);

      cubit.startWorkout();
      cubit.logSet(exerciseId: 1, exerciseName: 'Squat', weight: 100, reps: 5);
      await cubit.discardWorkout();
      // pump (not pumpAndSettle): the discarded-restore window ticker runs
      // every 30 s and would never let the fake clock settle.
      await tester.pump();

      expect(find.text('Restore discarded workout'), findsOneWidget);
      expect(find.text('Restore last workout'), findsNothing);

      // Restoring brings the discarded session back in progress.
      await tester.tap(find.text('Restore discarded workout'));
      await tester.pumpAndSettle();
      expect(cubit.state.isInProgress, isTrue);
      expect(cubit.state.sets.single.weight, 100);
      expect(find.text('End Workout'), findsOneWidget);
    });
  });
}
