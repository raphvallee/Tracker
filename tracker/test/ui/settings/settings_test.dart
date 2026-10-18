// Settings integration tests (lib/pages/settings/): the SettingsCubit
// (a HydratedCubit) and the SettingsPage widget. Pure weight-format / state
// round-trip logic is unit-tested separately: test/unit/settings_test.dart.

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

Future<void> pumpSettingsPage(WidgetTester tester) async {
  await pumpAppPage(
    tester,
    BlocProvider(create: (_) => SettingsCubit(), child: const SettingsPage()),
  );
}

void main() {
  setUp(() {
    HydratedBloc.storage = InMemoryStorage();
  });

  test(
    'SettingsCubit persists preferences and ignores legacy profile keys',
    () {
      final cubit = SettingsCubit();
      addTearDown(cubit.close);

      cubit.setUnit(WeightUnit.pounds);
      cubit.setNotificationsEnabled(false);
      cubit.setAnalyticsEnabled(false);

      final restored = SettingsState.fromJson({
        ...cubit.state.toJson(),
        'displayName': 'Legacy User',
        'email': 'legacy@example.com',
      });
      expect(restored.unit, WeightUnit.pounds);
      expect(restored.notificationsEnabled, isFalse);
      expect(restored.analyticsEnabled, isFalse);
      expect(restored.toJson().containsKey('displayName'), isFalse);
      expect(restored.toJson().containsKey('email'), isFalse);
    },
  );

  testWidgets('settings page replaces placeholder cards with controls', (
    tester,
  ) async {
    await pumpSettingsPage(tester);
    expect(find.text('Profile Settings'), findsNothing);
    expect(find.text('Units'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Privacy & Security'), findsOneWidget);
    expect(find.byType(FSwitch), findsNWidgets(2));
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.byType(FSwitch).first);
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.widget<FSwitch>(find.byType(FSwitch).first).value, isFalse);

    await tester.tap(find.text('kg'));
    await tester.pumpAndSettle();
    expect(find.text('lb'), findsOneWidget);
    await tester.tap(find.text('lb'));
    await tester.pumpAndSettle();
    expect(find.text('lb'), findsOneWidget);
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
}
