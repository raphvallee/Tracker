// No Isar here: the cubit's persistence and the repository-backed free-form
// flow live one per file in workout_*_test.dart (docs/TESTING_ISAR_CI.md).

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/ui/core/ui/set_type_chip.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/test_helpers.dart';

void main() {
  setUp(() {
    // In-memory storage: the real HydratedStorage does file I/O behind a
    // static lock that deadlocks the widget-test fake-async zone once the
    // app shell (HydratedCubits) is pumped - same setup as app_test.
    HydratedBloc.storage = InMemoryStorage();
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

    testWidgets('fractional reps log exactly and below one is an error', (
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

      await tester.enterText(repsField, '0.4');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(cubit.state.sets, hasLength(1));
      expect(find.text('Must be at least 1'), findsOneWidget);
    });
  });

  group('Free workout cards', () {
    Future<WorkoutCubit> pumpFree(
      WidgetTester tester, {
      void Function(WorkoutCubit cubit)? seed,
    }) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      final cubit = await pumpApp(tester);
      cubit.startWorkout();
      seed?.call(cubit);
      tester
          .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
          .onChange!(2);
      await tester.pumpAndSettle();
      return cubit;
    }

    void logBench(WorkoutCubit cubit, double weight) => cubit.logSet(
      exerciseId: 1,
      exerciseName: 'Bench Press',
      weight: weight,
      reps: 5,
    );

    Finder input(int index) => find
        .descendant(
          of: find.byType(FTextField).at(index),
          matching: find.byType(EditableText),
        )
        .first;

    String textOf(WidgetTester tester, int index) =>
        tester.widget<EditableText>(input(index)).controller.text;

    Future<void> commit(WidgetTester tester) async {
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }

    testWidgets('each exercise gets its own card, in logged order', (
      tester,
    ) async {
      await pumpFree(
        tester,
        seed: (cubit) {
          cubit.addExercise(exerciseId: 1, name: 'Bench Press');
          logBench(cubit, 80);
          // Sets logged without a card (older saved sessions) get one too.
          cubit.logSet(
            exerciseId: 2,
            exerciseName: 'Squat',
            weight: 100,
            reps: 5,
          );
        },
      );

      expect(find.text('Free workout'), findsOneWidget);
      expect(find.text('1. '), findsOneWidget);
      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('2. '), findsOneWidget);
      expect(find.text('Squat'), findsOneWidget);
      // One logged row per card, and no blank row after it.
      expect(find.byType(FTextField), findsNWidgets(4));
      expect(find.text('Add set'), findsNWidgets(2));
      expect(find.text('Add exercise'), findsOneWidget);
      expect(find.byType(FCheckbox), findsNothing);
      // FSelect redirects to a private subclass: match it by predicate.
      expect(find.byWidgetPredicate((w) => w is FSelect<int>), findsNothing);
      expect(textOf(tester, 0), '80');
      expect(textOf(tester, 2), '100');
    });

    testWidgets('a set typed in a lower blank row fills the first one', (
      tester,
    ) async {
      final cubit = await pumpFree(
        tester,
        seed: (cubit) => cubit.addExercise(exerciseId: 1, name: 'Bench Press'),
      );
      await tester.tap(find.text('Add set'));
      await tester.pumpAndSettle();
      expect(find.byType(FTextField), findsNWidgets(4));

      await tester.enterText(input(2), '60');
      await tester.enterText(input(3), '5');
      await commit(tester);

      expect(cubit.state.sets, hasLength(1));
      expect(find.byType(FTextField), findsNWidgets(4));
      expect(
        [for (var i = 0; i < 4; i++) textOf(tester, i)],
        ['60', '5', '', ''],
      );

      // Leaving the logged row again must not log it twice.
      await tester.enterText(input(1), '5');
      await commit(tester);
      expect(cubit.state.sets, hasLength(1));
    });

    testWidgets('clearing a logged row shifts the later sets up', (
      tester,
    ) async {
      final cubit = await pumpFree(
        tester,
        seed: (cubit) {
          cubit.addExercise(exerciseId: 1, name: 'Bench Press');
          for (final weight in [60.0, 70.0, 80.0]) {
            logBench(cubit, weight);
          }
        },
      );
      expect(find.byType(FTextField), findsNWidgets(6));

      await tester.enterText(input(2), '');
      await tester.enterText(input(3), '');
      await commit(tester);

      expect(cubit.state.sets.map((s) => s.weight).toList(), [60, 80]);
      expect(find.byType(FTextField), findsNWidgets(4));
      expect(
        [for (var i = 0; i < 4; i++) textOf(tester, i)],
        ['60', '5', '80', '5'],
      );
    });

    testWidgets('the set chip toggles warm-up before or after logging', (
      tester,
    ) async {
      final cubit = await pumpFree(
        tester,
        seed: (cubit) => cubit.addExercise(exerciseId: 1, name: 'Bench Press'),
      );
      Finder chip(int row) => find.byType(SetTypeChip).at(row);

      // Before typing: the blank row logs as a warm-up.
      await tester.tap(chip(0));
      await tester.pump();
      expect(find.text('W'), findsOneWidget);
      await tester.enterText(input(0), '40');
      await tester.enterText(input(1), '10');
      await commit(tester);
      expect(cubit.state.sets.single.isWarmup, isTrue);

      // On a logged row: flips the logged set.
      await tester.tap(chip(0));
      await tester.pumpAndSettle();
      expect(cubit.state.sets.single.isWarmup, isFalse);

      await tester.tap(find.text('Add set'));
      await tester.pumpAndSettle();

      // A mouse click blurs the typed row first, logging it, and the toggle
      // then lands on the logged set.
      await tester.enterText(input(2), '60');
      await tester.enterText(input(3), '8');
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(chip(1)));
      await mouse.down(tester.getCenter(chip(1)));
      await mouse.up();
      await tester.pumpAndSettle();
      expect(cubit.state.sets, hasLength(2));
      expect(cubit.state.sets.last.weight, 60);
      expect(cubit.state.sets.last.isWarmup, isTrue);
      expect(find.text('W'), findsOneWidget);
      // Move the mouse off and let the chip's hover tooltip timers run out.
      await mouse.removePointer();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('removing an exercise with sets asks first', (tester) async {
      final cubit = await pumpFree(
        tester,
        seed: (cubit) {
          cubit.addExercise(exerciseId: 1, name: 'Bench Press');
          logBench(cubit, 80);
        },
      );

      await tester.tap(find.byIcon(FLucideIcons.x));
      await tester.pumpAndSettle();
      expect(find.text('Remove Bench Press?'), findsOneWidget);
      expect(
        find.text('This will delete its 1 set from this workout.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(cubit.state.sets, hasLength(1));

      await tester.tap(find.byIcon(FLucideIcons.x));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(cubit.state.sets, isEmpty);
      expect(cubit.state.plan, isEmpty);
      expect(find.text('Bench Press'), findsNothing);
      expect(
        find.text('Add an exercise to start logging sets.'),
        findsOneWidget,
      );
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
