import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/number_entry.dart';
import 'package:tracker/main.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';

/// A tall window: the Ahem test font draws every glyph a full em wide, so
/// narrow windows overflow labels that fit with real fonts.
void useTallWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

SettingsCubit settingsOf(WidgetTester tester) =>
    tester.element(find.byType(MyApp)).read<SettingsCubit>();

/// Switches to the Workout tab through the nav bar's onChange: hit-testing
/// is brittle under the Offstage nested navigators.
Future<void> openWorkoutTab(WidgetTester tester) async {
  tester
      .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
      .onChange!(2);
  await tester.pumpAndSettle();
}

/// Opens [name]'s page from the running workout's overview.
Future<void> openExercise(
  WidgetTester tester,
  String name, {
  NumberEntry entry = NumberEntry.phoneKeyboard,
  bool prefill = true,
}) async {
  settingsOf(tester)
    ..setNumberEntry(entry)
    ..setPrefillSets(prefill);
  await openWorkoutTab(tester);
  await tester.tap(find.text(name).first);
  await tester.pumpAndSettle();
}

/// The weight field of set row [row] on the exercise page.
Finder weightField(int row) => find
    .byWidgetPredicate(
      (w) => w is TextField && w.focusNode?.debugLabel == 'set weight',
    )
    .at(row);

/// The reps field of set row [row] on the exercise page.
Finder repsField(int row) => find
    .byWidgetPredicate(
      (w) => w is TextField && w.focusNode?.debugLabel == 'set reps',
    )
    .at(row);

/// A control by its semantics label, matched on the widget itself (the
/// semantics tree may merge a label with its neighbours'). An animated
/// FTappable wraps a second one with the same label: the outer one is it.
Finder labelled(String label) => find
    .byWidgetPredicate(
      (w) =>
          (w is Semantics && w.properties.label == label) ||
          (w is FTappable && w.semanticsLabel == label),
    )
    .first;

String textIn(WidgetTester tester, Finder field) =>
    tester.widget<TextField>(field).controller!.text;

/// Types a set into row [row], leaving the row's focus where it is.
Future<void> typeSet(
  WidgetTester tester,
  int row, {
  String? weight,
  String? reps,
}) async {
  if (weight != null) await tester.enterText(weightField(row), weight);
  if (reps != null) await tester.enterText(repsField(row), reps);
}

/// Leaves the focused row, which is what saves it.
Future<void> leaveRow(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}
