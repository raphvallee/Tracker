// CurrentWorkout tab widget tests (lib/ui/workout/): planned logging, row
// commits, reps validation and the restore buttons. No Isar here: the
// cubit's persistence and the repository-backed free-form flow live one per
// file in workout_*_test.dart (docs/TESTING_ISAR_CI.md).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/domain/models/workout_split.dart';
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

      // The plan title and exercise render.
      expect(find.text('PPL · Push'), findsOneWidget);
      expect(find.text('Bench Press'), findsOneWidget);
      // Planned logging has an add button but no warm-up toggle: leaving the
      // row (here: the keyboard's done action unfocusing) commits it instead.
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
      // There is no rendered-set display: the set keeps living in its input.
      expect(find.text('100 kg × 5'), findsNothing);
      expect(tester.widget<EditableText>(weightField).controller.text, '100');
      expect(tester.widget<EditableText>(repsField).controller.text, '5');

      // Retyping both values and leaving again edits the same set in place -
      // it never becomes a duplicate.
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

      // Planned rows are not swipeable: dragging does nothing and never opens
      // the delete dialog (the plan itself sizes the rows).
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

      // The planned sets render as a summary line, and the editor shows one
      // weight/reps row per planned set, captioned with the set number and
      // targeting the plan through hints - never pre-filled values.
      expect(find.text('Planned: 3 × 10, 8-12'), findsNothing);
      final fields = find.byType(FTextField);
      expect(fields, findsNWidgets(6)); // 3 rows × (weight + reps)
      String hintOf(int index) =>
          tester.widget<FTextField>(fields.at(index)).hint!;
      expect(hintOf(1), '10');
      expect(hintOf(3), '8-12');
      expect(hintOf(5), '8-12');
      expect(find.text('Set'), findsNWidgets(3));
      // Set order is not shown: no row numbers.
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

      // Row 1 commits when focus leaves it - here via the keyboard's done
      // action - and stays in its inputs; exactly one of three planned sets
      // is logged.
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

      // Tapping into the next row commits the previous one, with no
      // keyboard shortcut involved.
      await tester.enterText(fieldText(2), '80');
      await tester.enterText(fieldText(3), '8');
      await tester.enterText(fieldText(4), '90');
      await tester.pumpAndSettle();

      expect(cubit.state.sets, hasLength(2));
      expect(cubit.state.sets.last.weight, 80);
      expect(cubit.state.sets.last.reps, 8);
      // Row 1 keeps serving the first set; row 2 is the committed one; row 3
      // still holds the just-typed values waiting for its own commit.
      expect(tester.widget<EditableText>(fieldText(0)).controller.text, '100');
      expect(tester.widget<EditableText>(fieldText(2)).controller.text, '80');
      expect(tester.widget<EditableText>(fieldText(4)).controller.text, '90');
      // There are exactly three planned rows - the plan, not the log count,
      // sizes the form.
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

      // Row 1 commits on blur; row 2 only has a weight typed, so blurring it
      // surfaces the missing-reps error and commits nothing for that row.
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
      // The error stays until the row is completed: filling reps and leaving
      // again logs the row.
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

      // "3.25" logs as 3.25 - no rounding anywhere. The keyboard's done
      // action moves focus away, which commits the row.
      await tester.enterText(weightField, '100');
      await tester.enterText(repsField, '3.25');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(cubit.state.sets, hasLength(1));
      expect(cubit.state.sets.single.reps, 3.25);

      // A fraction below one rep shows an explicit error, never a no-op.
      await tester.enterText(repsField, '0.4');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(cubit.state.sets, hasLength(1));
      expect(find.text('Must be at least 1'), findsOneWidget);
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

      expect(find.text('Restore last workout'), findsOneWidget);
      expect(find.text('Restore discarded workout'), findsNothing);

      // Restoring brings the discarded session back in progress.
      await tester.tap(find.text('Restore last workout'));
      await tester.pumpAndSettle();
      expect(cubit.state.isInProgress, isTrue);
      expect(cubit.state.sets.single.weight, 100);
      expect(find.text('End Workout'), findsOneWidget);
    });
  });
}
