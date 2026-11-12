import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/domain/models/effort_scale.dart';
import 'package:tracker/domain/models/number_entry.dart';
import 'package:tracker/domain/models/rep_mode.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/settings/widgets/settings_page.dart';
import 'package:tracker/ui/settings/widgets/splits_settings_page.dart';
import 'package:tracker/ui/settings/widgets/workout_settings_page.dart';

import '../../../testing/test_helpers.dart';

void main() {
  SettingsCubit settingsOf(WidgetTester tester, Type page) =>
      BlocProvider.of<SettingsCubit>(tester.element(find.byType(page)));

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  testWidgets('home sums up each part and opens its page', (tester) async {
    await pumpAppPage(tester, const SettingsPage());
    final cubit = settingsOf(tester, SettingsPage);

    expect(find.text('Keypad entry, prefilled sets, RPE'), findsOneWidget);
    expect(find.text('New exercises start at 8-12 reps'), findsOneWidget);
    expect(find.text('Add the gyms you train at'), findsOneWidget);
    expect(find.text('Kilograms'), findsOneWidget);
    // Only settings that change something are listed.
    expect(find.text('Notifications'), findsNothing);
    expect(find.text('Privacy & Security'), findsNothing);
    // Nothing on the page builds a text field or a select: the first frame
    // stays cheap.
    expect(find.byType(FTextField), findsNothing);
    expect(find.byType(FSelect<Object?>), findsNothing);

    await tapText(tester, 'Weight unit');
    expect(find.text('Weights show in lb.'), findsOneWidget);
    await tapText(tester, 'Pounds');
    expect(cubit.state.unit, WeightUnit.pounds);
    expect(find.text('Weights show in lb.'), findsNothing, reason: 'closed');
    expect(find.text('Pounds'), findsOneWidget);

    await tapText(tester, 'Workout');
    expect(find.byType(WorkoutSettingsPage), findsOneWidget);
    expect(find.text('Logging sets'), findsOneWidget);
  });

  testWidgets('workout page sets how sets are logged', (tester) async {
    await pumpAppPage(tester, const WorkoutSettingsPage());
    final cubit = settingsOf(tester, WorkoutSettingsPage);

    await tapText(tester, 'Prefill sets');
    expect(cubit.state.prefillSets, isFalse);

    await tapText(tester, 'Number entry');
    await tapText(tester, 'Steppers');
    expect(cubit.state.numberEntry, NumberEntry.steppers);
    await tapText(tester, 'Number entry');
    await tapText(tester, 'Phone keyboard');
    expect(cubit.state.numberEntry, NumberEntry.phoneKeyboard);
    expect(find.text('Phone keyboard'), findsOneWidget);

    await tapText(tester, 'Effort rating');
    await tapText(tester, 'RIR');
    expect(cubit.state.effortScale, EffortScale.rir);

    expect(
      find.text('Ask before logging more than 500 kg, in case of a typo'),
      findsOneWidget,
    );
    await tapText(tester, 'Confirm heavy weights');
    expect(cubit.state.showHeavyWeightWarning, isFalse);
    await tapText(tester, 'Confirm heavy weights');
    expect(cubit.state.showHeavyWeightWarning, isTrue, reason: 'back on');
  });

  testWidgets('splits page edits the rep target new exercises start at', (
    tester,
  ) async {
    await pumpAppPage(tester, const SplitsSettingsPage());
    final cubit = settingsOf(tester, SplitsSettingsPage);
    expect(find.text('8-12 reps'), findsOneWidget);

    await tapText(tester, 'Rep target');
    expect(find.text('Warm-up set'), findsNothing);
    await tapText(tester, 'Fixed reps');
    await tapText(tester, 'Done');
    expect(cubit.state.defaultRepMode, RepMode.fixed);
    expect(cubit.state.defaultReps, 8);
    expect(find.text('8 reps'), findsOneWidget);

    await tapText(tester, 'Rep target');
    await tapText(tester, 'Rep range');
    await tester.tap(find.bySemanticsLabel('More max'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Done');
    expect(cubit.state.defaultRepMode, RepMode.range);
    expect(cubit.state.defaultRepRangeMin, 8);
    expect(cubit.state.defaultRepRangeMax, 13);
    expect(find.text('8-13 reps'), findsOneWidget);

    // Closing the sheet without Done keeps the edit.
    await tapText(tester, 'Rep target');
    await tester.tap(find.bySemanticsLabel('More min'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsNothing, reason: 'closed');
    expect(cubit.state.defaultRepRangeMin, 9);
    expect(find.text('9-13 reps'), findsOneWidget);

    // A range that does not make sense is dropped on close.
    await tapText(tester, 'Rep target');
    await tester.enterText(find.byType(TextField).first, '20');
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(cubit.state.defaultRepRangeMin, 9);
    expect(cubit.state.defaultRepRangeMax, 13);
  });
}
