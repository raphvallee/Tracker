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

  group('showGymPicker', () {
    final gyms = [
      Gym(name: 'Home', isPrimary: true)..id = 1,
      Gym(name: 'Commercial', order: 1)..id = 2,
    ];

    testWidgets('marks the gym in use and returns the one picked', (
      tester,
    ) async {
      await pumpApp(tester);
      final context = tester.element(find.byType(Navigator).first);
      Object? picked;
      unawaited(
        showGymPicker(
          context,
          gyms,
          currentId: 1,
          oneWorkoutOnly: true,
        ).then((r) => picked = r),
      );
      await tester.pumpAndSettle();

      expect(find.text('Training at'), findsOneWidget);
      expect(find.text('Home gym'), findsOneWidget);
      expect(find.byIcon(FLucideIcons.check), findsOneWidget);
      expect(
        find.text(
          'Another gym counts for this workout only. The next one starts at '
          'Home.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Commercial'));
      await tester.pumpAndSettle();

      expect((picked as Gym?)?.name, 'Commercial');
    });

    testWidgets('closing the sheet without a choice returns null', (
      tester,
    ) async {
      await pumpApp(tester);
      final context = tester.element(find.byType(Navigator).first);
      var completed = false;
      Object? picked = const Object();
      unawaited(
        showGymPicker(context, gyms).then((r) {
          completed = true;
          picked = r;
        }),
      );
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(picked, isNull);
    });

    testWidgets('a gym added from the sheet asks for its name only', (
      tester,
    ) async {
      await pumpApp(tester);
      final context = tester.element(find.byType(Navigator).first);
      unawaited(showGymPicker(context, gyms));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add a gym'));
      await tester.pumpAndSettle();
      expect(find.text('New gym'), findsOneWidget);
      expect(find.widgetWithText(FTextField, 'Gym name'), findsOneWidget);
      expect(find.textContaining('multiplier'), findsNothing);
      expect(find.textContaining('Description'), findsNothing);
    });
  });
}
