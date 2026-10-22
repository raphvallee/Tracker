// Weight rules on the current-workout set form: the -1000..10000 range, the
// assisted-machine prompt for negative weights, the heavy-weight prompt above
// 500 kg / 1000 lb, and the "Don't show this again" preference. See
// lib/ui/core/ui/weight_confirmation.dart and utils/form_validators.dart.
// In-memory storage only, so these are plain widget tests (no Isar).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/main.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/test_helpers.dart';

void main() {
  setUp(() {
    HydratedBloc.storage = InMemoryStorage();
  });

  Future<WorkoutCubit> pumpLogger(
    WidgetTester tester, {
    WeightUnit unit = WeightUnit.kilograms,
  }) async {
    final cubit = await pumpApp(tester, unit: unit);
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
    return cubit;
  }

  Finder inputOf(int index) => find
      .descendant(
        of: find.byType(FTextField).at(index),
        matching: find.byType(EditableText),
      )
      .first;

  String textOf(WidgetTester tester, int index) =>
      tester.widget<EditableText>(inputOf(index)).controller.text;

  Future<void> enterSet(
    WidgetTester tester, {
    required String weight,
    String reps = '5',
  }) async {
    await tester.enterText(inputOf(0), weight);
    await tester.enterText(inputOf(1), reps);
  }

  Future<void> addSet(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Add set'));
    await tester.tap(find.text('Add set'));
    await tester.pumpAndSettle();
  }

  Future<void> tapInDialog(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(of: find.byType(FDialog), matching: find.text(label)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tickDontShowAgain(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(FDialog),
        matching: find.byType(FCheckbox),
      ),
    );
    await tester.pump();
  }

  SettingsCubit settingsOf(WidgetTester tester) =>
      tester.element(find.byType(MyApp)).read<SettingsCubit>();

  group('negative weight (assisted machine)', () {
    testWidgets('asks first and logs only when confirmed', (tester) async {
      final cubit = await pumpLogger(tester);
      await enterSet(tester, weight: '-20', reps: '8');
      await addSet(tester);

      expect(find.text('Assisted machine?'), findsOneWidget);
      expect(cubit.state.sets, isEmpty);

      await tapInDialog(tester, 'Yes, log it');
      expect(cubit.state.sets.single.weight, -20);
      expect(find.text('-20 kg × 8'), findsOneWidget);
    });

    testWidgets('going back logs nothing and keeps the typed values', (
      tester,
    ) async {
      final cubit = await pumpLogger(tester);
      await enterSet(tester, weight: '-20', reps: '8');
      await addSet(tester);
      await tapInDialog(tester, 'Go back');

      expect(find.text('Assisted machine?'), findsNothing);
      expect(cubit.state.sets, isEmpty);
      expect(textOf(tester, 0), '-20');
      expect(textOf(tester, 1), '8');
    });

    testWidgets('minus 1000 is the lowest accepted weight', (tester) async {
      final cubit = await pumpLogger(tester);
      await enterSet(tester, weight: '-1000');
      await addSet(tester);
      await tapInDialog(tester, 'Yes, log it');

      expect(cubit.state.sets.single.weight, -1000);
    });

    testWidgets('below minus 1000 is rejected without a prompt', (
      tester,
    ) async {
      final cubit = await pumpLogger(tester);
      await enterSet(tester, weight: '-1001');
      await addSet(tester);

      expect(find.text('Must be between -1000 and 10000'), findsOneWidget);
      expect(find.text('Assisted machine?'), findsNothing);
      expect(cubit.state.sets, isEmpty);
    });

    testWidgets('negative zero is a plain zero and skips the prompt', (
      tester,
    ) async {
      final cubit = await pumpLogger(tester);
      await enterSet(tester, weight: '-0');
      await addSet(tester);

      expect(find.text('Assisted machine?'), findsNothing);
      expect(cubit.state.sets.single.weight, 0);
      expect(cubit.state.sets.single.weight.isNegative, isFalse);
      expect(find.text('0 kg × 5'), findsOneWidget);
    });
  });

  group('zero and range', () {
    testWidgets('zero is a valid bodyweight entry', (tester) async {
      final cubit = await pumpLogger(tester);
      await enterSet(tester, weight: '0');
      await addSet(tester);

      expect(cubit.state.sets.single.weight, 0);
      expect(find.text('0 kg × 5'), findsOneWidget);
    });

    testWidgets('an empty weight shows the range message', (tester) async {
      final cubit = await pumpLogger(tester);
      await enterSet(tester, weight: '');
      await addSet(tester);

      expect(find.text('Must be between -1000 and 10000'), findsOneWidget);
      expect(cubit.state.sets, isEmpty);
    });

    testWidgets('above 10000 is rejected without a prompt', (tester) async {
      final cubit = await pumpLogger(tester);
      await enterSet(tester, weight: '10001');
      await addSet(tester);

      expect(find.text('Must be between -1000 and 10000'), findsOneWidget);
      expect(find.text("That's a lot of weight"), findsNothing);
      expect(cubit.state.sets, isEmpty);
    });

    testWidgets(
      '10000 is the highest accepted weight, after the heavy prompt',
      (tester) async {
        final cubit = await pumpLogger(tester);
        await enterSet(tester, weight: '10000');
        await addSet(tester);
        await tapInDialog(tester, 'Use this weight');

        expect(cubit.state.sets.single.weight, 10000);
      },
    );
  });

  group('two decimals', () {
    testWidgets('weight keeps two decimals and drops a third', (tester) async {
      final cubit = await pumpLogger(tester);
      await enterSet(tester, weight: '82.255');
      expect(textOf(tester, 0), '82.25');
      await addSet(tester);

      expect(cubit.state.sets.single.weight, 82.25);
      expect(find.text('82.25 kg × 5'), findsOneWidget);
    });
  });

  group('heavy weight (kilograms)', () {
    testWidgets('500 kg is the last weight without a prompt', (tester) async {
      final cubit = await pumpLogger(tester);
      await enterSet(tester, weight: '500');
      await addSet(tester);

      expect(find.text("That's a lot of weight"), findsNothing);
      expect(cubit.state.sets.single.weight, 500);
    });

    testWidgets('above 500 kg asks, and going back logs nothing', (
      tester,
    ) async {
      final cubit = await pumpLogger(tester);
      await enterSet(tester, weight: '500.5');
      await addSet(tester);

      expect(find.text("That's a lot of weight"), findsOneWidget);
      expect(find.textContaining('500.5 kg is above 500 kg'), findsOneWidget);
      await tapInDialog(tester, 'Go back');
      expect(cubit.state.sets, isEmpty);
    });

    testWidgets('confirming logs the weight and the prompt comes back', (
      tester,
    ) async {
      final cubit = await pumpLogger(tester);
      await enterSet(tester, weight: '600');
      await addSet(tester);
      await tapInDialog(tester, 'Use this weight');
      expect(cubit.state.sets.single.weight, 600);

      await enterSet(tester, weight: '700');
      await addSet(tester);
      expect(find.text("That's a lot of weight"), findsOneWidget);
      expect(settingsOf(tester).state.showHeavyWeightWarning, isTrue);
    });

    testWidgets('the first heavy prompt has no checkbox', (tester) async {
      final cubit = await pumpLogger(tester);
      await enterSet(tester, weight: '700');
      await addSet(tester);

      expect(find.text("That's a lot of weight"), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FDialog),
          matching: find.text("Don't show this again"),
        ),
        findsNothing,
      );
      expect(settingsOf(tester).state.heavyWeightConfirmed, isFalse);

      await tapInDialog(tester, 'Use this weight');
      expect(cubit.state.sets.single.weight, 700);
      expect(settingsOf(tester).state.heavyWeightConfirmed, isTrue);

      await enterSet(tester, weight: '750');
      await addSet(tester);
      expect(find.text("That's a lot of weight"), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FDialog),
          matching: find.text("Don't show this again"),
        ),
        findsOneWidget,
      );
    });

    testWidgets("'Don't show this again' silences later prompts", (
      tester,
    ) async {
      final cubit = await pumpLogger(tester);
      await enterSet(tester, weight: '700');
      await addSet(tester);
      await tapInDialog(tester, 'Use this weight');

      await enterSet(tester, weight: '750');
      await addSet(tester);
      await tickDontShowAgain(tester);
      await tapInDialog(tester, 'Use this weight');
      expect(settingsOf(tester).state.showHeavyWeightWarning, isFalse);
      expect(cubit.state.sets.last.weight, 750);

      await enterSet(tester, weight: '800');
      await addSet(tester);
      expect(find.text("That's a lot of weight"), findsNothing);
      expect(cubit.state.sets.last.weight, 800);
    });

    testWidgets('the checkbox saves nothing unless the weight is confirmed', (
      tester,
    ) async {
      final cubit = await pumpLogger(tester);
      await enterSet(tester, weight: '700');
      await addSet(tester);
      await tapInDialog(tester, 'Use this weight');

      await enterSet(tester, weight: '750');
      await addSet(tester);
      await tickDontShowAgain(tester);
      await tapInDialog(tester, 'Go back');

      expect(settingsOf(tester).state.showHeavyWeightWarning, isTrue);
      expect(cubit.state.sets.length, 1);

      await addSet(tester);
      expect(find.text("That's a lot of weight"), findsOneWidget);
    });
  });

  group('heavy weight (pounds)', () {
    testWidgets('1000 lb is not heavy, even though it is over 500', (
      tester,
    ) async {
      final cubit = await pumpLogger(tester, unit: WeightUnit.pounds);
      await enterSet(tester, weight: '1000');
      await addSet(tester);

      expect(find.text("That's a lot of weight"), findsNothing);
      expect(cubit.state.sets.single.weight, closeTo(453.59, 0.01));
      expect(find.text('1000 lb × 5'), findsOneWidget);
    });

    testWidgets('above 1000 lb asks and reports the pound threshold', (
      tester,
    ) async {
      final cubit = await pumpLogger(tester, unit: WeightUnit.pounds);
      await enterSet(tester, weight: '1000.5');
      await addSet(tester);

      expect(find.textContaining('1000.5 lb is above 1000 lb'), findsOneWidget);
      await tapInDialog(tester, 'Go back');
      expect(cubit.state.sets, isEmpty);
    });
  });
}
