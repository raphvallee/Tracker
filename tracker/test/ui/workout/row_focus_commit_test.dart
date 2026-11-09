import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/test_helpers.dart';
import '../../../testing/workout_helpers.dart';

final _plan = [
  PlannedSet(order: 0, minReps: 10),
  PlannedSet(order: 1, minReps: 8, maxReps: 12),
  PlannedSet(order: 2, minReps: 6),
];

Future<WorkoutCubit> pumpPlan(WidgetTester tester) async {
  useTallWindow(tester);
  final cubit = await pumpApp(tester);
  cubit.startPlanWorkout(
    title: 'Push',
    exercises: [
      PlanExercise(exerciseId: 1, name: 'Bench Press', order: 0, sets: _plan),
    ],
  );
  await openExercise(tester, 'Bench Press');
  return cubit;
}

/// Taps the page title: a tap outside the fields is what leaves a row.
Future<void> tapOutside(WidgetTester tester) async {
  await tester.tap(find.text('Bench Press').last);
  await tester.pumpAndSettle();
}

List<String> texts(WidgetTester tester, int rows) => [
  for (var i = 0; i < rows; i++) ...[
    textIn(tester, weightField(i)),
    textIn(tester, repsField(i)),
  ],
];

void main() {
  setUp(() => HydratedBloc.storage = InMemoryStorage());

  testWidgets('each row saves on tap outside (rows 1 to 3)', (tester) async {
    final cubit = await pumpPlan(tester);
    for (var row = 0; row < 3; row++) {
      await typeSet(tester, row, weight: '${60 + row}', reps: '${10 - row}');
      await tapOutside(tester);
      expect(cubit.state.sets, hasLength(row + 1), reason: 'row ${row + 1}');
    }
    expect(cubit.state.sets.map((s) => (s.weight, s.reps)), [
      (60, 10),
      (61, 9),
      (62, 8),
    ]);
  });

  testWidgets('add set adds a row beyond the plan and logging keeps it', (
    tester,
  ) async {
    final cubit = await pumpPlan(tester);
    expect(find.byType(TextField), findsNWidgets(6));

    await tester.tap(find.text('Add set'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(8));

    await typeSet(tester, 3, weight: '40', reps: '12');
    await tapOutside(tester);
    expect(cubit.state.sets.single.reps, 12);
    // Logging never takes rows away: plan, plus the added one.
    expect(find.byType(TextField), findsNWidgets(8));
  });

  testWidgets('a row filled out of order logs into the first open row', (
    tester,
  ) async {
    final cubit = await pumpPlan(tester);

    await typeSet(tester, 2, weight: '80', reps: '6');
    await tapOutside(tester);

    expect(cubit.state.sets, hasLength(1));
    expect(find.byType(TextField), findsNWidgets(6));
    expect(texts(tester, 3), ['80', '6', '', '', '', '']);
  });

  testWidgets('clearing a logged row leaves no stale copy behind', (
    tester,
  ) async {
    final cubit = await pumpPlan(tester);
    for (final weight in [60.0, 70.0, 80.0]) {
      cubit.logSet(
        exerciseId: 1,
        exerciseName: 'Bench Press',
        weight: weight,
        reps: 5,
      );
    }
    await tester.pumpAndSettle();

    await typeSet(tester, 1, weight: '', reps: '');
    await tapOutside(tester);

    expect(cubit.state.sets.map((s) => s.weight).toList(), [60, 80]);
    expect(texts(tester, 3), ['60', '5', '80', '5', '', '']);
  });

  testWidgets('a logged set stays editable: a corrected rep count saves', (
    tester,
  ) async {
    final cubit = await pumpPlan(tester);
    await typeSet(tester, 0, weight: '60', reps: '8');
    await tapOutside(tester);
    expect(cubit.state.sets.single.reps, 8);

    await typeSet(tester, 0, reps: '7');
    await tapOutside(tester);
    expect(cubit.state.sets, hasLength(1));
    expect(cubit.state.sets.single.reps, 7);
    expect(cubit.state.sets.single.weight, 60);
  });
}
