import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/ui/workout/widgets/gym_picker.dart';

import '../../../testing/test_helpers.dart';

void main() {
  const emptyError = 'Cannot be empty';

  Future<void> openNewGymSheet(WidgetTester tester) async {
    await pumpApp(tester);
    unawaited(
      editGymSheet(
        tester.element(find.byType(Navigator).first),
        title: 'New Gym',
        initial: Gym(name: ''),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the name error shows only after Save and typing clears it', (
    tester,
  ) async {
    await openNewGymSheet(tester);
    expect(find.text('New Gym'), findsOneWidget);
    expect(find.text(emptyError), findsNothing);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text(emptyError), findsOneWidget);
    expect(find.text('New Gym'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(FTextField, 'Gym name'),
      'Main Gym',
    );
    await tester.pumpAndSettle();

    expect(find.text(emptyError), findsNothing);
  });

  group('promptGym', () {
    final gyms = [
      Gym(name: 'Home', isPrimary: true),
      Gym(name: 'Commercial', order: 1),
    ];

    testWidgets('picking a gym returns it', (tester) async {
      await pumpApp(tester);
      final context = tester.element(find.byType(Navigator).first);
      GymPick? pick;
      unawaited(promptGym(context, gyms).then((r) => pick = r));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Commercial'));
      await tester.pumpAndSettle();

      expect(pick?.gym?.name, 'Commercial');
    });

    testWidgets('closing the picker without a choice returns no pick', (
      tester,
    ) async {
      await pumpApp(tester);
      final context = tester.element(find.byType(Navigator).first);
      var completed = false;
      GymPick? pick;
      unawaited(
        promptGym(context, gyms).then((r) {
          completed = true;
          pick = r;
        }),
      );
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(pick, isNull);
    });
  });
}
