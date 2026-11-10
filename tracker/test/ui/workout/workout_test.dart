// No Isar here: the cubit's persistence and the repository-backed flows live
// one per file in workout_*_test.dart (docs/TESTING_ISAR_CI.md).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/domain/models/effort_scale.dart';
import 'package:tracker/domain/models/number_entry.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';
import 'package:tracker/ui/workout/widgets/elapsed_clock.dart';
import 'package:tracker/ui/workout/widgets/number_entry.dart';
import 'package:tracker/ui/workout/widgets/workout_overview.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/test_helpers.dart';
import '../../../testing/workout_helpers.dart';

List<PlannedSet> _sets(int count, int min, [int? max]) => [
  for (var i = 0; i < count; i++)
    PlannedSet(order: i, minReps: min, maxReps: max),
];

Future<WorkoutCubit> pumpPush(WidgetTester tester) async {
  useTallWindow(tester);
  final cubit = await pumpApp(tester);
  cubit.startPlanWorkout(
    title: 'Push Day',
    splitTitle: 'PPL',
    exercises: [
      PlanExercise(
        exerciseId: 1,
        name: 'Bench Press',
        order: 0,
        sets: _sets(2, 8, 12),
      ),
      PlanExercise(
        exerciseId: 2,
        name: 'Overhead Press',
        order: 1,
        sets: _sets(3, 6, 8),
      ),
    ],
  );
  return cubit;
}

Finder logButton() => find.textContaining(RegExp(r'^Log '));

void main() {
  setUp(() => HydratedBloc.storage = InMemoryStorage());

  group('Overview', () {
    testWidgets('lists the plan with the next exercise first in line', (
      tester,
    ) async {
      final cubit = await pumpPush(tester);
      cubit.logSet(
        exerciseId: 1,
        exerciseName: 'Bench Press',
        weight: 60,
        reps: 8,
      );
      await openWorkoutTab(tester);

      expect(find.text('Push Day'), findsOneWidget);
      expect(find.text('Finish'), findsOneWidget);
      expect(find.text('1 of 5 sets'), findsOneWidget);
      // Each exercise counts its sets on the right; the next step is docked.
      expect(find.text('1 of 2'), findsOneWidget);
      expect(find.text('0 of 3'), findsOneWidget);
      expect(find.text('6-8 reps'), findsOneWidget);
      expect(find.text('Continue Bench Press'), findsOneWidget);
      expect(
        find.byType(ElapsedClock),
        findsNWidgets(2),
        reason: 'header and tab',
      );

      await tester.tap(find.text('Continue Bench Press'));
      await tester.pumpAndSettle();
      expect(logButton(), findsOneWidget);
      expect(find.text('Push Day, exercise 1 of 2'), findsOneWidget);
      expect(find.text('Aim for 8-12 reps'), findsOneWidget);
      expect(find.text('Resting'), findsOneWidget, reason: 'a set is in');
    });

    testWidgets('a finished exercise shrinks to its best set', (tester) async {
      final cubit = await pumpPush(tester);
      for (final weight in [80.0, 82.5]) {
        cubit.logSet(
          exerciseId: 1,
          exerciseName: 'Bench Press',
          weight: weight,
          reps: 8,
        );
      }
      await openWorkoutTab(tester);

      expect(find.text('Best set 82.5 kg × 8'), findsOneWidget);
      expect(find.text('2 of 2'), findsOneWidget);
      expect(find.text('Overhead Press'), findsOneWidget);
      expect(find.text('0 of 3'), findsOneWidget);
      expect(find.text('Continue Overhead Press'), findsOneWidget);
    });

    testWidgets('the dock offers Finish once the plan is done', (tester) async {
      final cubit = await pumpPush(tester);
      for (final (id, name, count) in [
        (1, 'Bench Press', 2),
        (2, 'Overhead Press', 3),
      ]) {
        for (var i = 0; i < count; i++) {
          cubit.logSet(exerciseId: id, exerciseName: name, weight: 60, reps: 8);
        }
      }
      await openWorkoutTab(tester);

      await tester.tap(find.text('Finish workout'));
      await tester.pumpAndSettle();
      expect(find.text('Finish Push Day?'), findsOneWidget);
      expect(find.textContaining('not done'), findsNothing);
      await tester.tap(find.text('Save workout'));
      await tester.pumpAndSettle();
      expect(cubit.state.isInProgress, isFalse);
    });

    testWidgets('swiping an exercise away asks first when it has sets', (
      tester,
    ) async {
      final cubit = await pumpPush(tester);
      cubit.logSet(
        exerciseId: 1,
        exerciseName: 'Bench Press',
        weight: 60,
        reps: 8,
      );
      await openWorkoutTab(tester);

      await tester.drag(find.text('Bench Press'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text('Remove Bench Press?'), findsOneWidget);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(cubit.state.plan.map((e) => e.name), ['Overhead Press']);
      expect(cubit.state.sets, isEmpty);

      await tester.drag(find.text('Overhead Press'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.textContaining('Remove Overhead'), findsNothing);
      expect(cubit.state.plan, isEmpty);
      expect(
        find.text('Add an exercise to start logging sets.'),
        findsOneWidget,
      );
    });

    testWidgets('Finish saves; with nothing logged it offers to discard', (
      tester,
    ) async {
      final cubit = await pumpPush(tester);
      await openWorkoutTab(tester);

      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      expect(find.text('Discard workout?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      cubit.logSet(
        exerciseId: 1,
        exerciseName: 'Bench Press',
        weight: 60,
        reps: 8,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      expect(find.text('Finish Push Day?'), findsOneWidget);
      expect(find.text('4 planned sets are not done.'), findsOneWidget);
      expect(find.text('Bench Press, Overhead Press'), findsOneWidget);
      await tester.tap(find.text('Keep going'));
      await tester.pumpAndSettle();
      expect(cubit.state.isInProgress, isTrue);

      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save workout'));
      await tester.pumpAndSettle();
      expect(cubit.state.isInProgress, isFalse);
      expect(cubit.state.savedSnapshot!.planTitle, 'Push Day');
    });

    testWidgets('Finish also offers to discard the workout', (tester) async {
      final cubit = await pumpPush(tester);
      cubit.logSet(
        exerciseId: 1,
        exerciseName: 'Bench Press',
        weight: 60,
        reps: 8,
      );
      await openWorkoutTab(tester);

      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard workout'));
      await tester.pumpAndSettle();
      expect(
        find.text('This deletes the 1 set logged in this workout.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Discard workout').last);
      await tester.pumpAndSettle();
      expect(cubit.state.isInProgress, isFalse);
      expect(cubit.state.discardedSnapshot, isNotNull);
    });

    testWidgets('Discard workout in the menu discards after asking', (
      tester,
    ) async {
      final cubit = await pumpPush(tester);
      cubit.logSet(
        exerciseId: 1,
        exerciseName: 'Bench Press',
        weight: 60,
        reps: 8,
      );
      await openWorkoutTab(tester);

      await tester.tap(fButtonByTooltip('Workout options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard workout'));
      await tester.pumpAndSettle();
      expect(
        find.text('This deletes the 1 set logged in this workout.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Discard workout').last);
      await tester.pumpAndSettle();
      expect(cubit.state.isInProgress, isFalse);
      expect(cubit.state.discardedSnapshot, isNotNull);
    });
  });

  group('Exercise page', () {
    testWidgets('Log saves the placeholder values, one tap per set', (
      tester,
    ) async {
      final cubit = await pumpPush(tester);
      await openExercise(tester, 'Bench Press');

      // No history: the plan gives 8 reps, the weight is still missing.
      expect(find.text('Log set 1'), findsOneWidget);
      await tester.tap(find.text('Log set 1'));
      await tester.pumpAndSettle();
      expect(find.text('Must be between -1000 and 10000'), findsOneWidget);
      expect(cubit.state.sets, isEmpty);

      await typeSet(tester, 0, weight: '80');
      await tester.pump();
      // The focused field's keyboard bar repeats the dock's Log button.
      expect(find.text('Log 80 kg × 8'), findsNWidgets(2));
      await tester.tap(find.text('Log 80 kg × 8').first);
      await tester.pumpAndSettle();
      expect(cubit.state.sets.single.weight, 80);
      expect(cubit.state.sets.single.reps, 8);

      // The next row copies the weight above it.
      await tester.tap(find.text('Log 80 kg × 8'));
      await tester.pumpAndSettle();
      expect(cubit.state.sets.map((s) => (s.weight, s.reps)), [
        (80, 8),
        (80, 8),
      ]);

      expect(find.text('Next: Overhead Press'), findsOneWidget);
      await tester.tap(find.text('Next: Overhead Press'));
      await tester.pumpAndSettle();
      expect(find.text('Push Day, exercise 2 of 2'), findsOneWidget);
      expect(find.text('Aim for 6-8 reps'), findsOneWidget);
    });

    testWidgets('a tap anywhere on a waiting row makes it the set', (
      tester,
    ) async {
      await pumpPush(tester);
      await openExercise(tester, 'Bench Press');
      expect(find.text('Set 1'), findsOneWidget, reason: 'the open row');

      // The empty end of set 2's row, past its fields and badge.
      final reps = tester.getRect(repsField(1));
      await tester.tapAt(Offset(reps.right + 30, reps.center.dy));
      await tester.pumpAndSettle();
      expect(find.text('Set 2'), findsOneWidget);
      expect(find.text('Set 1'), findsNothing);
      expect(find.byType(NumberKeypad), findsNothing, reason: 'no field taken');
    });

    testWidgets('only the dock logs; it fills the row from the placeholder', (
      tester,
    ) async {
      final cubit = await pumpPush(tester);
      await openExercise(tester, 'Bench Press');
      await typeSet(tester, 0, weight: '70', reps: '10');
      await leaveRow(tester);
      expect(cubit.state.sets.single.reps, 10);
      expect(labelled('Set 1 logged'), findsOneWidget);
      // A waiting row has no button of its own to log it by mistake.
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Log set 2',
        ),
        findsNothing,
      );

      await tester.tap(find.text('Log 70 kg × 8'));
      await tester.pumpAndSettle();
      expect(cubit.state.sets.last.weight, 70);
      expect(cubit.state.sets.last.reps, 8, reason: 'the plan, not row 1');
      expect(textIn(tester, repsField(1)), '8');
    });

    testWidgets('typing one value and leaving logs it with the placeholder', (
      tester,
    ) async {
      final cubit = await pumpPush(tester);
      await openExercise(tester, 'Bench Press');
      await typeSet(tester, 0, weight: '90');
      await leaveRow(tester);
      expect(cubit.state.sets.single.reps, 8);
    });

    testWidgets('with prefill off a half-typed row shows its error', (
      tester,
    ) async {
      final cubit = await pumpPush(tester);
      await openExercise(tester, 'Bench Press', prefill: false);

      final hint = tester.widget<TextField>(repsField(0)).decoration!.hintText;
      expect(hint, 'Reps');
      await typeSet(tester, 0, weight: '90');
      await leaveRow(tester);
      expect(find.text('Must be between 0.1 and 2000'), findsOneWidget);
      expect(cubit.state.sets, isEmpty);
    });

    testWidgets('an error sits right under its own field', (tester) async {
      await pumpPush(tester);
      await openExercise(tester, 'Bench Press');
      await typeSet(tester, 0, weight: '60', reps: '0.05');
      await leaveRow(tester);

      final error = tester.getRect(find.text('Must be between 0.1 and 2000'));
      final field = tester.getRect(repsField(0));
      expect(error.top, greaterThan(field.bottom));
      expect(error.top - field.bottom, lessThan(40));
      expect(error.center.dx, closeTo(field.center.dx, 2));
    });

    testWidgets('partial reps log; outside 0.1 to 2000 is an error', (
      tester,
    ) async {
      final cubit = await pumpPush(tester);
      await openExercise(tester, 'Bench Press');
      await typeSet(tester, 0, weight: '60', reps: '0.05');
      await leaveRow(tester);
      expect(find.text('Must be between 0.1 and 2000'), findsOneWidget);
      expect(cubit.state.sets, isEmpty);

      await typeSet(tester, 0, reps: '0.5');
      await leaveRow(tester);
      expect(cubit.state.sets.single.reps, 0.5);
    });

    testWidgets('more than 200 reps asks first', (tester) async {
      final cubit = await pumpPush(tester);
      await openExercise(tester, 'Bench Press');
      await typeSet(tester, 0, weight: '20', reps: '250');
      await leaveRow(tester);
      expect(find.text("That's a lot of reps"), findsOneWidget);
      await tester.tap(find.text('Go back'));
      await tester.pumpAndSettle();
      expect(cubit.state.sets, isEmpty);

      await tester.tap(find.text('Log 20 kg × 250'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use these reps'));
      await tester.pumpAndSettle();
      expect(cubit.state.sets.single.reps, 250);

      // Changing only the weight of that set does not ask again.
      await typeSet(tester, 0, weight: '25');
      await leaveRow(tester);
      expect(find.text("That's a lot of reps"), findsNothing);
      expect(cubit.state.sets.single.weight, 25);
    });

    testWidgets('the set badge toggles warm-up before and after logging', (
      tester,
    ) async {
      final cubit = await pumpPush(tester);
      await openExercise(tester, 'Bench Press');

      await tester.tap(labelled('Set 1, tap for a warm-up'));
      await tester.pumpAndSettle();
      await typeSet(tester, 0, weight: '40', reps: '12');
      await leaveRow(tester);
      expect(cubit.state.sets.single.type, SetType.warmup);
      // Warm-ups do not count: the next row is working set 1.
      expect(find.text('Log 40 kg × 8'), findsOneWidget);
      expect(labelled('Set 1, tap for a warm-up'), findsOneWidget);

      await tester.tap(labelled('Warm-up set, tap for a working set'));
      await tester.pumpAndSettle();
      expect(cubit.state.sets.single.type, SetType.working);
    });

    testWidgets('planned warm-ups open as warm-up rows', (tester) async {
      useTallWindow(tester);
      final cubit = await pumpApp(tester);
      cubit.startPlanWorkout(
        title: 'Push Day',
        exercises: [
          PlanExercise(
            exerciseId: 1,
            name: 'Bench Press',
            sets: [
              PlannedSet(minReps: 12, isWarmup: true),
              PlannedSet(order: 1, minReps: 8, maxReps: 12),
            ],
          ),
        ],
      );
      expect(
        workoutEntries(cubit.state).single.planned,
        1,
        reason: 'warm-ups are not working sets',
      );
      await openExercise(tester, 'Bench Press', prefill: false);

      expect(find.text('Warm-up'), findsOneWidget, reason: 'the open row');
      expect(find.text('Aim for 12 reps'), findsOneWidget);
      expect(labelled('Warm-up set, tap for a working set'), findsOneWidget);
      expect(labelled('Set 1, tap for a warm-up'), findsOneWidget);
      await typeSet(tester, 0, weight: '40', reps: '12');
      await leaveRow(tester);
      expect(cubit.state.sets.single.type, SetType.warmup);
    });

    testWidgets('effort is picked from 0 to 10 on the scale Settings picks', (
      tester,
    ) async {
      final cubit = await pumpPush(tester);
      await openExercise(tester, 'Bench Press');

      // Rated in the open row before it is logged: Log carries it, on the
      // side, and the set keeps it.
      await tester.tap(labelled('Rate set 1 RPE 9'));
      await tester.pumpAndSettle();
      expect(find.text('RPE 9'), findsOneWidget, reason: 'beside Log');
      expect(cubit.state.sets, isEmpty);
      // A second tap on the picked value clears it.
      await tester.tap(labelled('Rate set 1 RPE 9'));
      await tester.pumpAndSettle();
      expect(find.text('RPE 9'), findsNothing);
      await tester.tap(labelled('Rate set 1 RPE 9'));
      await tester.pumpAndSettle();
      await typeSet(tester, 0, weight: '80', reps: '8');
      await leaveRow(tester);
      expect(cubit.state.sets.single.rpe, 9);

      // The rare values sit behind the strip's last chip, in the sheet.
      await tester.tap(labelled('Rate set 2, other RPE values'));
      await tester.pumpAndSettle();
      expect(
        find.text('Rate of perceived exertion, from 0 to 10'),
        findsOneWidget,
      );
      await tester.tap(labelled('RPE 4'));
      await tester.pumpAndSettle();
      expect(find.text('RPE 4'), findsOneWidget, reason: 'beside Log');
      await tester.tap(labelled('Rate set 2, other RPE values'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear rating'));
      await tester.pumpAndSettle();

      // A logged set is rated in place.
      await tester.tap(labelled('Set 1 RPE 9'));
      await tester.pumpAndSettle();
      await tester.tap(labelled('RPE 7'));
      await tester.pumpAndSettle();
      expect(cubit.state.sets.single.rpe, 7);

      // Reps in reserve show the same rating as 10 minus RPE.
      settingsOf(tester).setEffortScale(EffortScale.rir);
      await tester.pumpAndSettle();
      expect(labelled('Set 1 RIR 3'), findsOneWidget);
      expect(
        find.text('RIR'),
        findsNWidgets(2),
        reason: 'the column header and the open row',
      );
      await tester.tap(labelled('Set 1 RIR 3'));
      await tester.pumpAndSettle();
      expect(find.text('Reps in reserve, from 0 to 10'), findsOneWidget);
      await tester.tap(labelled('RIR 1'));
      await tester.pumpAndSettle();
      expect(cubit.state.sets.single.rpe, 9, reason: 'stored as RPE');

      await tester.tap(labelled('Set 1 RIR 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear rating'));
      await tester.pumpAndSettle();
      expect(cubit.state.sets.single.rpe, isNull);
      expect(labelled('Set 1 RIR, not rated'), findsOneWidget);
    });

    testWidgets('a logged set goes in two swipes, never one', (tester) async {
      final cubit = await pumpPush(tester);
      cubit.logSet(
        exerciseId: 1,
        exerciseName: 'Bench Press',
        weight: 60,
        reps: 8,
      );
      cubit.logSet(
        exerciseId: 1,
        exerciseName: 'Bench Press',
        weight: 65,
        reps: 8,
      );
      await openExercise(tester, 'Bench Press');

      Future<void> swipe() async {
        await tester.timedDrag(
          weightField(0),
          const Offset(-700, 0),
          const Duration(milliseconds: 300),
        );
        await tester.pumpAndSettle();
      }

      // However far it goes, one swipe only opens the row on Delete.
      await swipe();
      expect(cubit.state.sets, hasLength(2));
      expect(find.text('Delete'), findsOneWidget);
      // A tap on the row closes it again.
      await tester.tap(weightField(0), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Delete'), findsNothing);
      expect(cubit.state.sets, hasLength(2));

      // Two swipes delete it, no dialog.
      await swipe();
      await swipe();
      expect(find.byType(FDialog), findsNothing);
      expect(cubit.state.sets.single.weight, 65);
      expect(textIn(tester, weightField(0)), '65');

      // The revealed Delete is the other second step.
      await swipe();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(cubit.state.sets, isEmpty);
    });

    testWidgets('Remove from workout leaves the page', (tester) async {
      final cubit = await pumpPush(tester);
      await openExercise(tester, 'Bench Press');
      await tester.tap(fButtonByTooltip('Exercise options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from workout'));
      await tester.pumpAndSettle();
      expect(cubit.state.plan.map((e) => e.name), ['Overhead Press']);
      expect(find.text('Continue Overhead Press'), findsOneWidget);
    });
  });

  group('Number entry', () {
    testWidgets('the keypad types, Next moves to reps and Log saves', (
      tester,
    ) async {
      final cubit = await pumpPush(tester);
      await openExercise(tester, 'Bench Press', entry: NumberEntry.keypad);

      await tester.tap(weightField(0));
      await tester.pumpAndSettle();
      expect(find.text('Set 1 weight, in kg'), findsOneWidget);
      for (final key in ['1', '0', '2', '.', '5']) {
        await tester.tap(labelled(key));
        await tester.pump();
      }
      await tester.tap(labelled('Delete'));
      await tester.tap(labelled('Delete'));
      await tester.pump();
      expect(textIn(tester, weightField(0)), '102');

      await tester.tap(labelled('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Set 1 reps'), findsOneWidget);
      await tester.tap(labelled('6'));
      await tester.pump();
      expect(
        find.text('Log 102 kg × 6'),
        findsNWidgets(2),
        reason: 'dock and keypad',
      );
      await tester.tap(find.text('Log 102 kg × 6').last);
      await tester.pumpAndSettle();
      expect(cubit.state.sets.single.weight, 102);
      expect(cubit.state.sets.single.reps, 6);
      expect(find.text('Set 1 reps'), findsNothing, reason: 'keypad closed');
    });

    testWidgets('the keypad sign key logs an assisted weight', (tester) async {
      final cubit = await pumpPush(tester);
      await openExercise(tester, 'Bench Press', entry: NumberEntry.keypad);
      await tester.tap(weightField(0));
      await tester.pumpAndSettle();
      await tester.tap(labelled('2'));
      await tester.tap(labelled('0'));
      await tester.tap(labelled('Negative weight'));
      await tester.pump();
      expect(textIn(tester, weightField(0)), '-20');
      await tester.tap(labelled('Close keypad'));
      await tester.pumpAndSettle();
      expect(find.text('Assisted machine?'), findsOneWidget);
      await tester.tap(find.text('Yes, log it'));
      await tester.pumpAndSettle();
      expect(cubit.state.sets.single.weight, -20);
    });

    testWidgets('steppers nudge the values without a keyboard', (tester) async {
      final cubit = await pumpPush(tester);
      await openExercise(tester, 'Bench Press', entry: NumberEntry.steppers);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Aim for 8-12 reps'), findsOneWidget);

      for (var i = 0; i < 3; i++) {
        await tester.tap(labelled('Increase weight'));
      }
      await tester.tap(labelled('Increase reps'));
      await tester.pump();
      expect(find.text('Log 7.5 kg × 9'), findsOneWidget);
      await tester.tap(find.text('Log 7.5 kg × 9'));
      await tester.pumpAndSettle();
      expect(cubit.state.sets.single.weight, 7.5);
      expect(cubit.state.sets.single.reps, 9);

      // A logged set saves each nudge right away.
      await tester.tap(find.text('7.5').first);
      await tester.pumpAndSettle();
      await tester.tap(labelled('Decrease reps'));
      await tester.pumpAndSettle();
      expect(cubit.state.sets.single.reps, 8);
    });
  });

  group('Start view', () {
    testWidgets('a workout that just ended is not offered back here', (
      tester,
    ) async {
      useTallWindow(tester);
      final cubit = await pumpApp(tester);
      await openWorkoutTab(tester);

      cubit.startWorkout();
      cubit.logSet(exerciseId: 1, exerciseName: 'Squat', weight: 100, reps: 5);
      await cubit.endWorkout();
      await tester.pumpAndSettle();
      expect(cubit.state.canRestoreSaved(), isTrue);
      expect(find.text('Restore last workout'), findsNothing);

      cubit.startWorkout();
      cubit.logSet(exerciseId: 1, exerciseName: 'Squat', weight: 100, reps: 5);
      await cubit.discardWorkout();
      await tester.pumpAndSettle();
      expect(cubit.state.canRestoreDiscarded(), isTrue);
      expect(find.text('Restore last workout'), findsNothing);
    });

    testWidgets('with no split the start view offers an empty workout', (
      tester,
    ) async {
      useTallWindow(tester);
      final cubit = await pumpApp(tester);
      await openWorkoutTab(tester);
      expect(find.text('Plan your split'), findsOneWidget);
      // With no day to start, the dock is the only way in.
      expect(find.text('Empty workout'), findsNothing);
      await tester.tap(find.text('Start empty workout'));
      await tester.pumpAndSettle();
      expect(cubit.state.isInProgress, isTrue);
      expect(cubit.state.planTitle, isNull);
      expect(find.text('Free workout'), findsOneWidget);
      expect(find.byType(FButton), findsWidgets);
    });
  });
}
