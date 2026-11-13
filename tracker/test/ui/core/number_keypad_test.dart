import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/domain/models/number_entry.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/ui/core/ui/number_keypad.dart';

void main() {
  late double value;
  late List<KeypadKey> keys;
  setUp(() {
    value = 80;
    keys = [];
  });

  /// A keypad whose steppers move [value] in 2.5 kg steps, as a page would.
  Future<void> show(WidgetTester tester, {required bool ruler}) =>
      tester.pumpWidget(
        MaterialApp(
          home: FTheme(
            data: FTheme.neutral.light.touch,
            child: Material(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: StatefulBuilder(
                  builder: (context, setState) => NumberKeypad(
                    caption: 'Set 1 weight, in kg',
                    onKey: (key, _) => keys.add(key),
                    logLabel: 'Log set 1',
                    onLog: () {},
                    steps: KeypadSteps.weight(
                      ruler: ruler,
                      value: value,
                      unit: WeightUnit.kilograms,
                      last: 80,
                      onStep: (direction) =>
                          setState(() => value += 2.5 * direction),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Finder labelled(String label) => find.byWidgetPredicate(
    (w) =>
        (w is Semantics && w.properties.label == label) ||
        (w is FTappable && w.semanticsLabel == label),
  );

  Future<void> hold(WidgetTester tester, Finder target) async {
    final gesture = await tester.startGesture(tester.getCenter(target));
    await tester.pump(kLongPressTimeout);
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pumpAndSettle();
  }

  group('The keypad and steppers rocker', () {
    testWidgets('steps on a tap, repeats on a hold and scrubs on a drag', (
      tester,
    ) async {
      await show(tester, ruler: false);
      expect(find.text('2.5 kg'), findsOneWidget, reason: 'the step');

      await tester.tap(labelled('Increase weight').first);
      await tester.pump();
      expect(value, 82.5);
      await tester.tap(labelled('Decrease weight').first);
      await tester.tap(labelled('Decrease weight').first);
      await tester.pump();
      expect(value, 77.5);

      await hold(tester, labelled('Increase weight').first);
      expect(value, greaterThanOrEqualTo(77.5 + 3 * 2.5));

      final before = value;
      await tester.drag(labelled('Decrease weight').first, const Offset(0, 80));
      await tester.pumpAndSettle();
      expect(value, lessThanOrEqualTo(before - 2 * 2.5), reason: 'down takes');
    });

    testWidgets('keeps every key: sign beside 0, close beside the caption', (
      tester,
    ) async {
      await show(tester, ruler: false);
      for (final label in ['Delete', 'Negative weight', 'Next', '0', '.']) {
        expect(labelled(label), findsWidgets, reason: label);
      }
      await tester.tap(labelled('Close keypad').first);
      await tester.tap(labelled('Negative weight').first);
      await tester.pumpAndSettle();
      expect(keys, [KeypadKey.hide, KeypadKey.sign]);
    });
  });

  group('The keypad and ruler', () {
    testWidgets('its ends step once, a drag slides from tick to tick', (
      tester,
    ) async {
      await show(tester, ruler: true);
      expect(find.text('80 kg'), findsOneWidget, reason: 'the readout');

      await tester.tap(labelled('Increase weight').first);
      await tester.pump();
      expect(value, 82.5);
      expect(find.text('82.5 kg'), findsOneWidget);
      await tester.tap(labelled('Decrease weight').first);
      await tester.pump();
      expect(value, 80);

      final ruler = labelled('Drag to change the weight').first;
      await tester.timedDrag(
        ruler,
        const Offset(-100, 0),
        const Duration(milliseconds: 500),
      );
      await tester.pumpAndSettle();
      expect(value, greaterThan(80), reason: 'dragged left, it climbs');
      expect(value % 2.5, 0, reason: 'from tick to tick');

      final before = value;
      await tester.timedDrag(
        ruler,
        const Offset(100, 0),
        const Duration(milliseconds: 500),
      );
      await tester.pumpAndSettle();
      expect(value, lessThan(before));
      expect(value % 2.5, 0);
    });
  });

  test('the ruler makes the keypad taller', () {
    expect(
      NumberKeypad.heightOf(NumberEntry.keypadSteppers),
      NumberKeypad.height,
    );
    expect(
      NumberKeypad.heightOf(NumberEntry.keypadRuler),
      NumberKeypad.height + NumberKeypad.rulerHeight,
    );
  });
}
