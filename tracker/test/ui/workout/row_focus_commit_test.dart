import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/test_helpers.dart';

final _plan = [
  PlannedSet(order: 0, minReps: 10),
  PlannedSet(order: 1, minReps: 8, maxReps: 12),
  PlannedSet(order: 2, minReps: 6),
];

Finder field(int index) => find
    .descendant(
      of: find.byType(FTextField).at(index),
      matching: find.byType(EditableText),
    )
    .first;

Future<WorkoutCubit> pumpPlan(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  final cubit = await pumpApp(tester);
  cubit.startPlanWorkout(
    title: 'PPL',
    exercises: [
      PlanExercise(exerciseId: 1, name: 'Bench Press', order: 0, sets: _plan),
    ],
  );
  tester
      .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
      .onChange!(2);
  await tester.pumpAndSettle();
  return cubit;
}

void main() {
  setUp(() => HydratedBloc.storage = InMemoryStorage());

  testWidgets('each row saves on tap outside (rows 1 to 3)', (tester) async {
    final cubit = await pumpPlan(tester);
    for (var row = 0; row < 3; row++) {
      await tester.enterText(field(row * 2), '${60 + row}');
      await tester.enterText(field(row * 2 + 1), '${10 - row}');
      await tester.tap(find.text('Bench Press'));
      await tester.pumpAndSettle();
      expect(cubit.state.sets, hasLength(row + 1), reason: 'row ${row + 1}');
    }
  });

  testWidgets('add set adds a row beyond the plan and logs into it', (
    tester,
  ) async {
    final cubit = await pumpPlan(tester);
    expect(find.byType(FTextField), findsNWidgets(6));

    await tester.tap(find.text('Add set'));
    await tester.pumpAndSettle();
    expect(find.byType(FTextField), findsNWidgets(8));

    await tester.enterText(field(6), '40');
    await tester.enterText(field(7), '12');
    await tester.tap(find.text('Bench Press'));
    await tester.pumpAndSettle();
    expect(cubit.state.sets, hasLength(1));
    expect(cubit.state.sets.single.reps, 12);
    // The extra row was used up, so the three planned rows remain.
    expect(find.byType(FTextField), findsNWidgets(6));
  });
}
