import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/ui/core/ui/swipeable_text.dart';

const _long =
    'Single-Arm Cable Crossover Chest Fly With Slow Eccentric And Full Pause';

Future<void> _pump(WidgetTester tester, String text) => tester.pumpWidget(
  MaterialApp(
    // The base behavior adds a scrollbar on desktop for any axis; the app's
    // Material behavior would hide a regression for horizontal scrolling.
    scrollBehavior: const ScrollBehavior(),
    home: Scaffold(
      body: Center(child: SizedBox(width: 120, child: SwipeableText(text))),
    ),
  ),
);

double _offset(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;

void main() {
  testWidgets('swipes sideways with touch and mouse on one line', (
    tester,
  ) async {
    await _pump(tester, _long);
    expect(tester.getSize(find.byType(SwipeableText)).height, lessThan(30));

    await tester.drag(find.byType(SwipeableText), const Offset(-80, 0));
    await tester.pumpAndSettle();
    final afterTouch = _offset(tester);
    expect(afterTouch, greaterThan(0));

    await tester.drag(
      find.byType(SwipeableText),
      const Offset(-80, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(_offset(tester), greaterThan(afterTouch));
    expect(tester.takeException(), isNull);
  });

  testWidgets('never shows a scrollbar', (tester) async {
    await _pump(tester, _long);
    expect(find.byType(RawScrollbar), findsNothing);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SwipeableText)),
    );
    await gesture.moveBy(const Offset(-60, 0));
    await tester.pump();
    expect(find.byType(RawScrollbar), findsNothing);
    await gesture.up();
    await tester.pumpAndSettle();
  }, variant: TargetPlatformVariant.desktop());

  testWidgets('short text does not scroll', (tester) async {
    await _pump(tester, 'Squat');

    await tester.drag(find.byType(SwipeableText), const Offset(-80, 0));
    await tester.pumpAndSettle();
    expect(_offset(tester), 0);
  });
}
