import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/ui/workout/widgets/gym_picker.dart';

import '../../../testing/test_helpers.dart';

void main() {
  const emptyError = 'Cannot be empty';

  Future<void> openNewGymDialog(WidgetTester tester) async {
    await pumpApp(tester);
    unawaited(
      editGymDialog(
        tester.element(find.byType(Navigator).first),
        title: 'New Gym',
        initial: Gym(name: ''),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows no name error when the dialog opens', (tester) async {
    await openNewGymDialog(tester);

    expect(find.text('New Gym'), findsOneWidget);
    expect(find.text(emptyError), findsNothing);
  });

  testWidgets('Save with an empty name shows the name error', (tester) async {
    await openNewGymDialog(tester);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text(emptyError), findsOneWidget);
    expect(find.text('New Gym'), findsOneWidget);
  });

  testWidgets('typing a name clears the error', (tester) async {
    await openNewGymDialog(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text(emptyError), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(FTextField, 'Gym name'),
      'Main Gym',
    );
    await tester.pumpAndSettle();

    expect(find.text(emptyError), findsNothing);
  });
}
