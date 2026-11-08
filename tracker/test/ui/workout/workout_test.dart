import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:isar_community/isar.dart';
import 'package:tracker/data/services/db.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/muscle.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/main.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
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

        await isar.close();
        await cubit.endWorkout();

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

    test('saved workout can always be restored (leaving history)', () async {
      cubit.startWorkout();
      final originalStart = cubit.state.startTime;
      cubit.logSet(exerciseId: 1, exerciseName: 'Squat', weight: 100, reps: 5);
      await cubit.endWorkout();

      expect(cubit.state.isInProgress, isFalse);
      expect(cubit.state.canRestoreSaved(), isTrue);
      expect(cubit.state.savedSessionId, isNotNull);

      await cubit.restoreSavedWorkout();

      expect(cubit.state.isInProgress, isTrue);
      expect(cubit.state.sets.single.weight, 100);
      expect(cubit.state.sets.single.reps, 5);
      expect(cubit.state.canRestoreSaved(), isFalse);
      expect(await repo.sessions.getAll(), isEmpty);

      await cubit.endWorkout();
      expect(cubit.state.isInProgress, isFalse);
      expect(cubit.state.canRestoreSaved(), isTrue);
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

      expect(timed.state.isInProgress, isFalse);
      expect(timed.state.canRestoreDiscarded(now: now), isTrue);
      expect(timed.state.savedSnapshot, isNull);
      expect(await repo.sessions.getAll(), isEmpty);

      timed.restoreDiscardedWorkout();
      expect(timed.state.isInProgress, isTrue);
      expect(timed.state.sets.single.weight, 100);
      expect(timed.state.canRestoreDiscarded(now: now), isFalse);

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
      expect(cubit.state.canRestoreDiscarded(), isFalse);

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
    testWidgets('planned exercises log on blur and keep the typed values', (
      tester,
    ) async {
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

      expect(find.text('PPL · Push'), findsOneWidget);
      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('Add set'), findsOneWidget);
      expect(find.byType(FCheckbox), findsNothing);
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
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final state = cubit.state;
      expect(state.sets, hasLength(1));
      expect(state.sets.single.weight, 100);
      expect(state.sets.single.reps, 5);
      expect(find.text('100 kg × 5'), findsNothing);
      expect(tester.widget<EditableText>(weightField).controller.text, '100');
      expect(tester.widget<EditableText>(repsField).controller.text, '5');

      await tester.enterText(weightField, '120');
      await tester.enterText(repsField, '6');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final updated = cubit.state;
      expect(updated.sets, hasLength(1));
      expect(updated.sets.single.weight, 120);
      expect(updated.sets.single.reps, 6);
      expect(tester.widget<EditableText>(weightField).controller.text, '120');
      expect(tester.widget<EditableText>(repsField).controller.text, '6');

      await tester.timedDrag(
        weightField,
        const Offset(-250, 0),
        const Duration(milliseconds: 200),
      );
      await tester.pumpAndSettle();
      expect(find.text('Delete this set?'), findsNothing);
      expect(cubit.state.sets, hasLength(1));
    });

    testWidgets('free-form logging keeps the warm-up toggle and add button', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      // A free workout loads its exercise dropdown from the repository, so
      // pump the real shell scoped to a test Isar with one seeded exercise
      // (pumpApp has no RepositoryScope). Real Isar IO only progresses inside
      // tester.runAsync (same concession as pumpPersistenceApp), and there is
      // no tearDown close: native close never completes in the fake-async
      // zone, the temp DB dies with the test process instead.
      late TrackerRepository repo;
      late int exerciseId;
      await tester.runAsync(() async {
        final isar = await openTestIsar([
          WorkoutSessionSchema,
          ExerciseSchema,
          GymSchema,
        ], name: 'workout_ui_freeform');
        repo = TrackerRepository(isar);
        exerciseId = await repo.exercises.put(
          Exercise(
            title: 'Bench Press',
            primaryMuscle: [Muscle.chest],
            equipment: [Equipment.barbell],
          ),
        );
      });

      // Advances the tree with timed pumps while giving the real event loop
      // room to land widget-zone Isar reads (pumpAndSettle would hang on the
      // feed page's live Isar watcher, forever animating).
      Future<void> pumpUntil(Finder finder) async {
        for (var i = 0; i < 50; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          if (finder.evaluate().isNotEmpty) return;
        }
        fail('expected $finder to become visible');
      }

      final cubit = WorkoutCubit(repository: repo);
      addTearDown(cubit.close);
      await tester.pumpWidget(
        RepositoryProvider<TrackerRepository>.value(
          value: repo,
          child: RepositoryScope(
            repository: repo,
            child: MultiBlocProvider(
              providers: [
                BlocProvider<WorkoutCubit>.value(value: cubit),
                BlocProvider<SettingsCubit>(
                  create: (_) => SettingsCubit()..setUnit(WeightUnit.kilograms),
                ),
              ],
              child: const MyApp(),
            ),
          ),
        ),
      );
      await pumpUntil(find.byType(FBottomNavigationBar));

      cubit.startWorkout();
      tester
          .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
          .onChange!(2);
      await pumpUntil(find.text('Log a set'));

      // Free-form logging keeps its own affordances: the exercise dropdown,
      // the warm-up toggle and the Add set button (no planned hints). (The
      // exercise dropdown must match FSelect via a predicate: FSelect's
      // constructor redirects to a private subclass, so byType never matches.
      // It renders an internal read-only field too, so the form shows three
      // FTextFields: exercise, weight, reps.)
      final exerciseDropdown = find.byWidgetPredicate((w) => w is FSelect<int>);
      expect(find.text('Add set'), findsOneWidget);
      expect(find.byType(FCheckbox), findsOneWidget);
      expect(exerciseDropdown, findsOneWidget);
      expect(find.byType(FTextField), findsNWidgets(3));
      final repsField = find
          .descendant(
            of: find.byType(FTextField).at(2),
            matching: find.byType(EditableText),
          )
          .first;
      expect(
        tester.widget<FTextField>(find.byType(FTextField).at(2)).hint,
        'Reps',
      );
      expect(tester.widget<EditableText>(repsField).controller.text, '');

      tester
          .widget<FButton>(
            find.ancestor(
              of: find.text('Add set'),
              matching: find.byType(FButton),
            ),
          )
          .onPress!();
      await tester.pump();
      expect(find.byType(FTextField), findsNWidgets(5));
      final addedWeightText = find
          .descendant(
            of: find.byType(FTextField).at(3),
            matching: find.byType(EditableText),
          )
          .first;
      expect(tester.widget<EditableText>(addedWeightText).controller.text, '');
      expect(cubit.state.sets, isEmpty);

      // Pick the exercise through the dropdown's open picker (hit-testing the
      // popover's animated overlay is unreliable under the test zone, so
      // invoke the tile's press handler directly), then log a warm-up set via
      // the kept controls.
      await tester.tap(exerciseDropdown.first);
      await pumpUntil(find.text('Bench Press').hitTestable());
      tilePress() => tester
          .widget<FItem>(
            find
                .ancestor(
                  of: find.text('Bench Press'),
                  matching: find.byType(FItem),
                )
                .first,
          )
          .onPress!;
      tilePress()();
      // The tile's press hides the popover (auto-hide) before lifting the
      // selection; pump the hide animation to completion so the selection
      // lands and no animation timer outlives the test.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find
            .ancestor(
              of: find.text('Bench Press'),
              matching: find.byType(FItem),
            )
            .evaluate()
            .isEmpty) {
          break;
        }
      }
      await tester.pump();

      final weightField = find
          .descendant(
            of: find.byType(FTextField).at(1),
            matching: find.byType(EditableText),
          )
          .first;
      await tester.enterText(weightField, '50');
      await tester.enterText(repsField, '8');
      await tester.ensureVisible(find.byType(FCheckbox));
      await tester.tap(find.byType(FCheckbox));
      // Forui tappables (checkbox included) defer their press callbacks
      // through 100ms press/up timers; pump past them so the toggle lands and
      // no timer outlives the test.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final state = cubit.state;
      expect(state.sets, hasLength(1));
      expect(state.sets.single.exerciseId, exerciseId);
      expect(state.sets.single.exerciseName, 'Bench Press');
      expect(state.sets.single.type, SetType.warmup);
      expect(find.text('50 kg × 8'), findsNothing);
      expect(tester.widget<EditableText>(weightField).controller.text, '50');
      expect(tester.widget<EditableText>(repsField).controller.text, '8');
      expect(tester.widget<FCheckbox>(find.byType(FCheckbox)).value, isFalse);

      tester
          .widget<FButton>(
            find.ancestor(
              of: find.text('Add set'),
              matching: find.byType(FButton),
            ),
          )
          .onPress!();
      await tester.pumpAndSettle();
      expect(find.byType(FTextField), findsNWidgets(7));
      final nextWeightText = find
          .descendant(
            of: find.byType(FTextField).at(3),
            matching: find.byType(EditableText),
          )
          .first;
      expect(tester.widget<EditableText>(nextWeightText).controller.text, '');
      expect(cubit.state.sets, hasLength(1));

      final rowWidth =
          tester
              .getSize(
                find.ancestor(
                  of: find.byType(FTextField).first,
                  matching: find.byType(FCard),
                ),
              )
              .width -
          24;
      final bandEnd = rowWidth * 0.635 * 0.75;
      final fieldRect = tester.getRect(find.byType(FTextField).at(1));

      final bandGesture = await tester.startGesture(
        tester.getCenter(find.byType(FTextField).at(1)),
      );
      await bandGesture.moveBy(Offset(-bandEnd / 2, 0));
      await tester.pump();
      final halfBandTravel =
          fieldRect.left - tester.getRect(find.byType(FTextField).at(1)).left;
      expect(halfBandTravel, lessThan(bandEnd / 2));
      final cancelStartRect = tester.getRect(find.byType(FTextField).at(1));
      await bandGesture.up();
      await tester.pump();
      expect(tester.getRect(find.byType(FTextField).at(1)), cancelStartRect);
      await tester.pump(const Duration(milliseconds: 30));
      final earlySpring = tester.getRect(find.byType(FTextField).at(1)).left;
      expect(earlySpring, greaterThan(cancelStartRect.left));
      expect(earlySpring, lessThan(fieldRect.left));
      await tester.pump(const Duration(milliseconds: 30));
      final laterSpring = tester.getRect(find.byType(FTextField).at(1)).left;
      expect(laterSpring, greaterThan(earlySpring));
      expect(laterSpring, lessThan(fieldRect.left));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(FTextField).at(1)), fieldRect);
      expect(find.text('Delete this set?'), findsNothing);
      expect(cubit.state.sets, hasLength(1));

      final trackGesture = await tester.startGesture(
        tester.getCenter(find.byType(FTextField).at(1)),
      );
      await trackGesture.moveBy(Offset(-bandEnd - 10, 0));
      await tester.pump();
      final atBandEnd = tester.getRect(find.byType(FTextField).at(1)).left;
      expect(fieldRect.left - atBandEnd, lessThan(bandEnd));
      await trackGesture.moveBy(const Offset(-30, 0));
      await tester.pump();
      expect(
        tester.getRect(find.byType(FTextField).at(1)).left,
        closeTo(atBandEnd - 30, 6),
      );
      await trackGesture.cancel();
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(FTextField).at(1)), fieldRect);
      expect(cubit.state.sets, hasLength(1));

      await tester.timedDrag(
        find.byType(FTextField).at(1),
        Offset(-rowWidth * 0.6, 0),
        const Duration(milliseconds: 200),
      );
      await tester.pumpAndSettle();
      expect(find.text('Delete this set?'), findsNothing);
      expect(tester.getRect(find.byType(FTextField).at(1)), fieldRect);
      expect(cubit.state.sets, hasLength(1));

      final rowRect = tester.getRect(find.byType(FTextField).at(1));
      await tester.timedDrag(
        find.byType(FTextField).at(1),
        Offset(-rowWidth * 0.7, 0),
        const Duration(milliseconds: 200),
      );
      await tester.pumpAndSettle();
      expect(cubit.state.sets, hasLength(1));
      expect(find.text('Delete this set?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(cubit.state.sets, hasLength(1));
      expect(tester.getRect(find.byType(FTextField).at(1)), rowRect);
      expect(
        tester
            .widget<EditableText>(
              find
                  .descendant(
                    of: find.byType(FTextField).at(1),
                    matching: find.byType(EditableText),
                  )
                  .first,
            )
            .controller
            .text,
        '50',
      );

      await tester.timedDrag(
        find.byType(FTextField).at(1),
        Offset(-rowWidth * 1.1, 0),
        const Duration(milliseconds: 200),
      );
      await tester.pumpAndSettle();
      expect(find.text('Delete this set?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(cubit.state.sets, isEmpty);
      expect(find.byType(FTextField), findsNWidgets(5));
      expect(
        tester
            .widget<EditableText>(
              find
                  .descendant(
                    of: find.byType(FTextField).at(1),
                    matching: find.byType(EditableText),
                  )
                  .first,
            )
            .controller
            .text,
        '',
      );
      expect(
        tester
            .widget<EditableText>(
              find
                  .descendant(
                    of: find.byType(FTextField).at(3),
                    matching: find.byType(EditableText),
                  )
                  .first,
            )
            .controller
            .text,
        '',
      );

      expect(find.byIcon(FLucideIcons.trash2), findsNWidgets(2));
      await tester.timedDrag(
        find.byType(FTextField).at(1),
        Offset(-rowWidth * 0.7, 0),
        const Duration(milliseconds: 200),
      );
      await tester.pumpAndSettle();
      expect(find.text('Delete this set?'), findsNothing);
      expect(find.byType(FTextField), findsNWidgets(3));

      expect(find.byIcon(FLucideIcons.trash2), findsNothing);
      final loggingRowRect = tester.getRect(find.byType(FTextField).at(1));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(FTextField).at(1)),
      );
      await gesture.moveBy(const Offset(-200, 0));
      await tester.pump();
      final draggedRect = tester.getRect(find.byType(FTextField).at(1));
      expect(draggedRect.left, greaterThan(loggingRowRect.left - 60));
      expect(draggedRect.left, lessThan(loggingRowRect.left - 20));
      expect(find.byIcon(FLucideIcons.trash2), findsNothing);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(FTextField).at(1)), loggingRowRect);
      expect(find.text('Delete this set?'), findsNothing);
      expect(cubit.state.sets, isEmpty);

      await tester.timedDrag(
        find.byType(FTextField).at(1),
        Offset(-rowWidth * 1.1, 0),
        const Duration(milliseconds: 200),
      );
      await tester.pumpAndSettle();
      expect(find.text('Delete this set?'), findsNothing);
      expect(tester.getRect(find.byType(FTextField).at(1)), loggingRowRect);
      expect(cubit.state.sets, isEmpty);
      expect(find.byType(FTextField), findsNWidgets(3));
    });

    testWidgets('plan exercises show one row per remaining set with hints', (
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
              PlannedSet(order: 2, minReps: 8, maxReps: 12),
            ],
          ),
        ],
      );

      tester
          .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
          .onChange!(2);
      await tester.pumpAndSettle();

      expect(find.text('Planned: 3 × 10, 8-12'), findsNothing);
      final fields = find.byType(FTextField);
      expect(fields, findsNWidgets(6));
      String hintOf(int index) =>
          tester.widget<FTextField>(fields.at(index)).hint!;
      expect(hintOf(1), '10');
      expect(hintOf(3), '8-12');
      expect(hintOf(5), '8-12');
      expect(find.text('Set'), findsNWidgets(3));
      expect(find.text('1'), findsNothing);
      expect(find.text('2'), findsNothing);
      expect(find.text('3'), findsNothing);
      expect(
        tester
            .widget<EditableText>(
              find
                  .descendant(
                    of: fields.at(1),
                    matching: find.byType(EditableText),
                  )
                  .first,
            )
            .controller
            .text,
        '',
      );

      Finder fieldText(int index) => find
          .descendant(of: fields.at(index), matching: find.byType(EditableText))
          .first;

      await tester.enterText(fieldText(0), '100');
      await tester.enterText(fieldText(1), '10');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(cubit.state.sets, hasLength(1));
      expect(cubit.state.sets.single.weight, 100);
      expect(cubit.state.sets.single.reps, 10);
      expect(find.text('100 kg × 10'), findsNothing);
      expect(tester.widget<EditableText>(fieldText(0)).controller.text, '100');
      expect(tester.widget<EditableText>(fieldText(1)).controller.text, '10');

      await tester.enterText(fieldText(2), '80');
      await tester.enterText(fieldText(3), '8');
      await tester.enterText(fieldText(4), '90');
      await tester.pumpAndSettle();

      expect(cubit.state.sets, hasLength(2));
      expect(cubit.state.sets.last.weight, 80);
      expect(cubit.state.sets.last.reps, 8);
      expect(tester.widget<EditableText>(fieldText(0)).controller.text, '100');
      expect(tester.widget<EditableText>(fieldText(2)).controller.text, '80');
      expect(tester.widget<EditableText>(fieldText(4)).controller.text, '90');
      expect(fields, findsNWidgets(6));
    });

    testWidgets('a partially filled row commits nothing for itself', (
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
              PlannedSet(order: 1, minReps: 10),
              PlannedSet(order: 2, minReps: 10),
            ],
          ),
        ],
      );

      tester
          .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
          .onChange!(2);
      await tester.pumpAndSettle();

      final fields = find.byType(FTextField);
      Finder fieldText(int index) => find
          .descendant(of: fields.at(index), matching: find.byType(EditableText))
          .first;
      await tester.enterText(fieldText(0), '100');
      await tester.enterText(fieldText(1), '10');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(cubit.state.sets, hasLength(1));

      await tester.enterText(fieldText(2), '80');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(cubit.state.sets, hasLength(1));
      expect(find.text('Must be greater than 0'), findsOneWidget);
      await tester.enterText(fieldText(3), '8');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(cubit.state.sets, hasLength(2));
      expect(cubit.state.sets.last.weight, 80);
      expect(cubit.state.sets.last.reps, 8);
      expect(find.text('Must be greater than 0'), findsNothing);
    });

    testWidgets('fractional reps log and persist exactly (two decimals)', (
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
              PlannedSet(order: 1, minReps: 10),
            ],
          ),
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

      await tester.enterText(weightField, '100');
      await tester.enterText(repsField, '3.25');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(cubit.state.sets, hasLength(1));
      expect(cubit.state.sets.single.reps, 3.25);

      await tester.enterText(repsField, '3.255');
      expect(tester.widget<EditableText>(repsField).controller.text, '3.25');
      await tester.enterText(repsField, '3.25.5');
      expect(tester.widget<EditableText>(repsField).controller.text, '3.25');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(cubit.state.sets, hasLength(1));

      tester.widget<EditableText>(repsField).controller.text = '12.345';
      // Hand-setting text bypasses the focus too: put the field back on the
      // keyboard before the done action can unfocus-commit the row.
      await tester.showKeyboard(repsField);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(cubit.state.sets, hasLength(1));
      expect(cubit.state.sets.single.reps, 12.34);

      await tester.enterText(repsField, '0.4');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(cubit.state.sets, hasLength(1));
      expect(find.text('Must be at least 1'), findsOneWidget);

      await tester.enterText(repsField, '.5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(cubit.state.sets, hasLength(1));
      expect(find.text('Must be at least 1'), findsOneWidget);

      await tester.enterText(repsField, 'abc');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(cubit.state.sets, hasLength(1));
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

      expect(find.text('Restore last workout'), findsNothing);

      cubit.startWorkout();
      cubit.logSet(exerciseId: 1, exerciseName: 'Squat', weight: 100, reps: 5);
      await cubit.endWorkout();
      await tester.pumpAndSettle();

      expect(find.text('Restore last workout'), findsOneWidget);

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

      expect(find.text('Restore last workout'), findsOneWidget);
      expect(find.text('Restore discarded workout'), findsNothing);

      await tester.tap(find.text('Restore last workout'));
      await tester.pumpAndSettle();
      expect(cubit.state.isInProgress, isTrue);
      expect(cubit.state.sets.single.weight, 100);
      expect(find.text('End Workout'), findsOneWidget);
    });
  });
}
