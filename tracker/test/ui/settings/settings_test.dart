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

  testWidgets('workout defaults dialogs update the cubit', (tester) async {
    final cubit = SettingsCubit();
    await pumpAppPage(
      tester,
      BlocProvider.value(value: cubit, child: const SettingsPage()),
    );

    expect(find.text('Workout defaults'), findsOneWidget);
    // The page builds no text field; the values are edited in dialogs.
    expect(find.byType(FTextField), findsNothing);
    expect(find.byType(FSelect<Object?>), findsNothing);

    Future<void> openRow(String title) async {
      await tester.ensureVisible(find.text(title));
      await tester.pumpAndSettle();
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
    }

    await openRow('Default reps');
    await tester.enterText(find.widgetWithText(FTextField, 'Reps'), '0');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Must be at least 1'), findsOneWidget);
    expect(cubit.state.defaultReps, SettingsState.initialDefaultReps);

    await tester.enterText(find.widgetWithText(FTextField, 'Reps'), '12');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(cubit.state.defaultReps, 12);
    expect(find.text('12'), findsOneWidget);

    await openRow('Default rep range');
    await tester.enterText(find.widgetWithText(FTextField, 'Min'), '6');
    await tester.enterText(find.widgetWithText(FTextField, 'Max'), '9');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(cubit.state.defaultRepRangeMin, 6);
    expect(cubit.state.defaultRepRangeMax, 9);
    expect(find.text('6-9'), findsOneWidget);

    await openRow('Default rep range');
    await tester.enterText(find.widgetWithText(FTextField, 'Min'), '15');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Must be at least the min'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(cubit.state.defaultRepRangeMin, 6);
    expect(cubit.state.defaultRepRangeMax, 9);
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
