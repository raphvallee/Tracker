// Planned-set rows on the CurrentWorkout page: one weight/reps row per planned
// set with the planned reps as the hint, logging a row turns it into a tile,
// warm-ups never fill a planned slot, and extra sets beyond the plan still log.
// Widget-only (no Isar), so it can share a process with other widget tests.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/test_helpers.dart';
import '../../../testing/test_fonts.dart';

/// Planned sets for one exercise: fixed 10, range 8-12, fixed 6.
final _plan = [
  PlannedSet(order: 0, minReps: 10),
  PlannedSet(order: 1, minReps: 8, maxReps: 12),
  PlannedSet(order: 2, minReps: 6),
];

/// The per-row log buttons (check icon). The page has no other check icon.
final logButtons = find.byIcon(FLucideIcons.check);

/// Pumps the app on the CurrentWorkout tab with one plan exercise.
Future<WorkoutCubit> pumpPlan(
  WidgetTester tester, {
  List<PlannedSet> planned = const [],
  // Tall enough that the extra-set form and its button stay on screen.
  Size size = const Size(800, 1400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  final cubit = await pumpApp(tester);
  cubit.startPlanWorkout(
    title: 'PPL · Push',
    exercises: [
      PlanExercise(exerciseId: 1, name: 'Bench Press', order: 0, sets: planned),
    ],
  );
  tester
      .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
      .onChange!(2);
  await tester.pumpAndSettle();
  return cubit;
}

/// The editable text of the [index]-th FTextField on the page. Rows come first
/// (weight, reps per planned set), then the extra-set form.
Finder field(int index) => find
    .descendant(
      of: find.byType(FTextField).at(index),
      matching: find.byType(EditableText),
    )
    .first;

String textOf(WidgetTester tester, Finder field) =>
    tester.widget<EditableText>(field).controller.text;

/// Types [weight] and [reps] into the first planned row, then taps its log
/// button. After a row logs, the next open row moves into the first position.
Future<void> logFirstRow(
  WidgetTester tester, {
  required String weight,
  required String reps,
}) async {
  await tester.enterText(field(0), weight);
  await tester.enterText(field(1), reps);
  await tester.tap(logButtons.first);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    // Same in-memory storage as the other widget tests (see workout_test.dart).
    HydratedBloc.storage = InMemoryStorage();
  });

  group('planned-set rows', () {
    testWidgets('one row per planned set, with the planned reps as the hint', (
      tester,
    ) async {
      await pumpPlan(tester, planned: _plan);

      // Three planned rows plus the extra-set form: 4 pairs of fields.
      expect(find.byType(FTextField), findsNWidgets(8));
      expect(logButtons, findsNWidgets(3));

      // The targets are hints (placeholder text), never typed values.
      expect(find.text('10'), findsOneWidget);
      expect(find.text('8-12'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(textOf(tester, field(1)), isEmpty);
      expect(textOf(tester, field(3)), isEmpty);
      expect(textOf(tester, field(5)), isEmpty);

      // The summary line stays as the plan overview.
      expect(find.text('Planned: 3 × 10, 8-12, 6'), findsOneWidget);
    });

    testWidgets('logging a row turns it into a tile and keeps the rest open', (
      tester,
    ) async {
      final cubit = await pumpPlan(tester, planned: _plan);

      await logFirstRow(tester, weight: '100', reps: '10');

      expect(cubit.state.sets, hasLength(1));
      expect(cubit.state.sets.single.reps, 10);
      expect(cubit.state.sets.single.type, SetType.working);
      expect(find.text('100 kg × 10'), findsOneWidget);

      // Two planned rows remain open, with their hints.
      expect(logButtons, findsNWidgets(2));
      expect(find.text('8-12'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('a warm-up does not consume a planned slot', (tester) async {
      final cubit = await pumpPlan(tester, planned: _plan);

      // Warm-up through the extra-set form (the only place with the toggle).
      await tester.enterText(field(6), '40');
      await tester.enterText(field(7), '5');
      await tester.tap(find.byType(FCheckbox));
      await tester.pump();
      await tester.tap(find.text('Add set'));
      await tester.pumpAndSettle();

      expect(cubit.state.sets.single.type, SetType.warmup);
      expect(find.text('40 kg × 5'), findsOneWidget);
      // All three planned rows are still open.
      expect(logButtons, findsNWidgets(3));
      expect(find.text('10'), findsOneWidget);

      // The first working row still lands in the first planned slot.
      await logFirstRow(tester, weight: '100', reps: '10');
      expect(cubit.state.sets, hasLength(2));
      expect(cubit.state.sets.last.type, SetType.working);
      expect(logButtons, findsNWidgets(2));
      expect(find.text('8-12'), findsOneWidget);
    });

    testWidgets('extra sets beyond the plan log through the add-set form', (
      tester,
    ) async {
      final cubit = await pumpPlan(tester, planned: _plan);

      for (final weight in ['100', '102.5', '105']) {
        await logFirstRow(tester, weight: weight, reps: '8');
      }
      expect(cubit.state.sets, hasLength(3));
      // Every planned slot is filled, so no open rows remain.
      expect(logButtons, findsNothing);

      // The extra-set form still logs beyond the plan.
      await tester.enterText(field(0), '60');
      await tester.enterText(field(1), '12');
      await tester.tap(find.text('Add set'));
      await tester.pumpAndSettle();

      expect(cubit.state.sets, hasLength(4));
      expect(cubit.state.sets.last.reps, 12);
      expect(find.text('60 kg × 12'), findsOneWidget);
    });

    testWidgets('planned rows fit a 320px-wide screen', (tester) async {
      // Real Inter metrics (the default test font is much wider), so this
      // catches overflow the way it shows on a device. Any RenderFlex overflow
      // fails the test, so pumping is the check.
      await tester.runAsync(loadTestFonts);
      await pumpPlan(tester, planned: _plan, size: const Size(320, 568));
      await logFirstRow(tester, weight: '100', reps: '10');

      expect(find.byType(FTextField), findsNWidgets(6));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a plan without planned sets keeps the single add-set form', (
      tester,
    ) async {
      await pumpPlan(tester);

      expect(find.byType(FTextField), findsNWidgets(2));
      expect(logButtons, findsNothing);
      expect(find.text('No sets yet'), findsOneWidget);
    });
  });

  group('free-form logging', () {
    testWidgets('keeps the single add-set form with the exercise dropdown', (
      tester,
    ) async {
      final cubit = await pumpApp(tester);
      cubit.startWorkout();
      tester
          .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
          .onChange!(2);
      await tester.pumpAndSettle();

      expect(find.text('Log a set'), findsOneWidget);
      expect(find.text('Exercise'), findsOneWidget);
      // Dropdown (an FTextField under the hood) plus weight and reps.
      expect(find.byType(FTextField), findsNWidgets(3));
      expect(logButtons, findsNothing);
    });
  });

  group('WorkoutCubit set order', () {
    test(
      'warm-up and working sets keep logged order and type per exercise',
      () {
        final cubit = WorkoutCubit();
        addTearDown(cubit.close);

        cubit.logSet(
          exerciseId: 1,
          exerciseName: 'Bench Press',
          weight: 40,
          reps: 5,
          type: SetType.warmup,
        );
        cubit.logSet(
          exerciseId: 1,
          exerciseName: 'Bench Press',
          weight: 60,
          reps: 10,
        );

        final sets = cubit.state.setsByExercise[1]!;
        expect(sets.map((set) => set.type), [SetType.warmup, SetType.working]);
        expect(sets.map((set) => set.order), [0, 1]);
      },
    );
  });
}
