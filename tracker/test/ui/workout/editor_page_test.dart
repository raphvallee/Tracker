// The workout page (split list) renders the "Start Workout" button according
// to the StartWorkoutPlacement setting: before the splits, after them, or not
// at all.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/workout/widgets/editor_page.dart';

import '../../../testing/test_helpers.dart';

void main() {
  Future<SettingsCubit> openEditor(WidgetTester tester) async {
    await pumpApp(tester);
    final settings = tester
        .element(find.byType(Navigator).first)
        .read<SettingsCubit>();
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const EditorPage()),
      ),
    );
    await tester.pumpAndSettle();
    return settings;
  }

  double topOf(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dy;

  testWidgets('start button renders before the split list by default', (
    tester,
  ) async {
    await openEditor(tester);

    expect(find.text('Start Workout'), findsOneWidget);
    expect(
      topOf(tester, 'Start Workout'),
      lessThan(topOf(tester, 'New Split')),
    );
  });

  testWidgets('start button renders after the split list when configured', (
    tester,
  ) async {
    final settings = await openEditor(tester);

    settings.setFreeStartPlacement(FreeStartPlacement.after);
    await tester.pumpAndSettle();

    expect(find.text('Start Workout'), findsOneWidget);
    expect(
      topOf(tester, 'Start Workout'),
      greaterThan(topOf(tester, 'New Split')),
    );
  });

  testWidgets('start button is hidden when configured', (tester) async {
    final settings = await openEditor(tester);

    settings.setFreeStartPlacement(FreeStartPlacement.disabled);
    await tester.pumpAndSettle();

    expect(find.text('Start Workout'), findsNothing);
    expect(find.text('New Split'), findsOneWidget);
  });
}
