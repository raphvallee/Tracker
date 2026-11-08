// SettingsPage widget tests (lib/ui/settings/): the workout-default inputs and
// the start-workout placement update the SettingsCubit. SettingsState
// round-trips are unit-tested in settings_cubit_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/settings/widgets/settings_page.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/test_helpers.dart';

void main() {
  setUp(() {
    HydratedBloc.storage = InMemoryStorage();
  });

  testWidgets('workout defaults fields update the cubit', (tester) async {
    final cubit = SettingsCubit();
    await pumpAppPage(
      tester,
      BlocProvider.value(value: cubit, child: const SettingsPage()),
    );

    expect(find.text('Workout defaults'), findsOneWidget);
    EditableText fieldOf(String label) => tester.widget<EditableText>(
      find
          .descendant(
            of: find.widgetWithText(FTextField, label),
            matching: find.byType(EditableText),
          )
          .first,
    );

    await tester.enterText(find.widgetWithText(FTextField, 'Reps'), '12');
    expect(fieldOf('Reps').controller.text, '12');
    expect(cubit.state.defaultReps, 12);

    await tester.enterText(find.widgetWithText(FTextField, 'Min'), '6');
    await tester.enterText(find.widgetWithText(FTextField, 'Max'), '9');
    expect(cubit.state.defaultRepRangeMin, 6);
    expect(cubit.state.defaultRepRangeMax, 9);

    // A crossed range (min > max) is rejected: state unchanged, error shown.
    await tester.enterText(find.widgetWithText(FTextField, 'Min'), '15');
    await tester.pumpAndSettle();
    expect(cubit.state.defaultRepRangeMin, 6);
    expect(find.text('Must be at least the min'), findsOneWidget);
  });

  testWidgets('start workout placement is configurable', (tester) async {
    final cubit = SettingsCubit();
    await pumpAppPage(
      tester,
      BlocProvider.value(value: cubit, child: const SettingsPage()),
    );

    expect(find.text('Start workout button'), findsOneWidget);
    expect(cubit.state.freeStartPlacement, FreeStartPlacement.before);

    await tester.tap(find.text('Before splits'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('After splits'));
    await tester.pumpAndSettle();
    expect(cubit.state.freeStartPlacement, FreeStartPlacement.after);

    await tester.tap(find.text('After splits'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hidden'));
    await tester.pumpAndSettle();
    expect(cubit.state.freeStartPlacement, FreeStartPlacement.disabled);
  });
}
