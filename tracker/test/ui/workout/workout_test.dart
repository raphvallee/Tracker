// No Isar here: the cubit's persistence and the repository-backed flows live
// one per file in workout_*_test.dart (docs/TESTING_ISAR_CI.md).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/domain/models/number_entry.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';
import 'package:tracker/ui/workout/widgets/elapsed_clock.dart';

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
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('1 of 2 sets'), findsOneWidget);
      expect(find.text('3 sets of 6-8 reps'), findsOneWidget);
      expect(
        find.byType(ElapsedClock),
        findsNWidgets(2),
        reason: 'header and tab',
      );

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(logButton(), findsOneWidget);
      expect(find.text('Target: 2 sets of 8-12 reps'), findsOneWidget);
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
      expect(find.text('0 of 3 sets'), findsOneWidget, reason: 'now current');
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
      expect(find.text('End workout?'), findsOneWidget);
      await tester.tap(find.text('End & save'));
      await tester.pumpAndSettle();
      expect(cubit.state.isInProgress, isFalse);
      expect(cubit.state.savedSnapshot!.planTitle, 'Push Day');
    });

    testWidgets('Cancel workout in the menu discards after asking', (
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
      await tester.tap(find.text('Cancel workout'));
      await tester.pumpAndSettle();
      expect(
        find.text('This deletes the 1 set logged in this workout.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel workout').last);
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
      expect(find.text('Target: 3 sets of 6-8 reps'), findsOneWidget);
    });

    testWidgets(
      'the circle logs its own row, filling it from the placeholder',
      (tester) async {
        final cubit = await pumpPush(tester);
        await openExercise(tester, 'Bench Press');
        await typeSet(tester, 0, weight: '70', reps: '10');
        await leaveRow(tester);
        expect(cubit.state.sets.single.reps, 10);

        await tester.tap(labelled('Log set 2'));
        await tester.pumpAndSettle();
        expect(cubit.state.sets.last.weight, 70);
        expect(cubit.state.sets.last.reps, 8, reason: 'the plan, not row 1');
        expect(textIn(tester, repsField(1)), '8');
      },
    );

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
      expect(find.text('Must be greater than 0'), findsOneWidget);
      expect(cubit.state.sets, isEmpty);
    });

    testWidgets('fractional reps log exactly and below one is an error', (
      tester,
    ) async {
      final cubit = await pumpPush(tester);
      await openExercise(tester, 'Bench Press');
      await typeSet(tester, 0, weight: '60', reps: '0.5');
      await leaveRow(tester);
      expect(find.text('Must be at least 1'), findsOneWidget);
      expect(cubit.state.sets, isEmpty);

      await typeSet(tester, 0, reps: '7.5');
      await leaveRow(tester);
      expect(cubit.state.sets.single.reps, 7.5);
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

    testWidgets('swiping a logged set away deletes it after confirming', (
      tester,
    ) async {
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

      await tester.timedDrag(
        weightField(0),
        const Offset(-700, 0),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();
      expect(find.text('Delete this set?'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(FDialog),
          matching: find.text('Delete'),
        ),
      );
      await tester.pumpAndSettle();
      expect(cubit.state.sets.single.weight, 65);
      expect(textIn(tester, weightField(0)), '65');
    });

    testWidgets('Remove from workout leaves the page', (tester) async {
      final cubit = await pumpPush(tester);
      await openExercise(tester, 'Bench Press');
      await tester.tap(fButtonByTooltip('Exercise options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from workout'));
      await tester.pumpAndSettle();
      expect(cubit.state.plan.map((e) => e.name), ['Overhead Press']);
      expect(find.text('Continue'), findsOneWidget);
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
      expect(find.text('Hold a number to type it'), findsOneWidget);

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

  group('Restore buttons', () {
    testWidgets('the last saved workout offers a restore button', (
      tester,
    ) async {
      useTallWindow(tester);
      final cubit = await pumpApp(tester);
      await openWorkoutTab(tester);
      expect(find.text('Restore last workout'), findsNothing);

      cubit.startWorkout();
      cubit.logSet(exerciseId: 1, exerciseName: 'Squat', weight: 100, reps: 5);
      await cubit.endWorkout();
      await tester.pump();
      expect(find.text('Restore last workout'), findsOneWidget);

      await tester.tap(find.text('Restore last workout'));
      await tester.pumpAndSettle();
      expect(cubit.state.isInProgress, isTrue);
      expect(cubit.state.sets.single.weight, 100);
      expect(find.text('Finish'), findsOneWidget);
      expect(find.text('Restore last workout'), findsNothing);
    });

    testWidgets('the last discarded workout offers a restore button', (
      tester,
    ) async {
      useTallWindow(tester);
      final cubit = await pumpApp(tester);
      await openWorkoutTab(tester);

      cubit.startWorkout();
      cubit.logSet(exerciseId: 1, exerciseName: 'Squat', weight: 100, reps: 5);
      await cubit.discardWorkout();
      // pump (not pumpAndSettle): the restore window ticker runs every 30 s.
      await tester.pump();
      expect(find.text('Restore last workout'), findsOneWidget);

      await tester.tap(find.text('Restore last workout'));
      await tester.pumpAndSettle();
      expect(cubit.state.isInProgress, isTrue);
      expect(cubit.state.sets.single.weight, 100);
    });

    testWidgets('with no split the start view offers an empty workout', (
      tester,
    ) async {
      useTallWindow(tester);
      final cubit = await pumpApp(tester);
      await openWorkoutTab(tester);
      expect(find.text('Plan your split'), findsOneWidget);
      await tester.tap(find.text('Start empty workout'));
      await tester.pumpAndSettle();
      expect(cubit.state.isInProgress, isTrue);
      expect(cubit.state.planTitle, isNull);
      expect(find.text('Free workout'), findsOneWidget);
      expect(find.byType(FButton), findsWidgets);
    });
  });
}
