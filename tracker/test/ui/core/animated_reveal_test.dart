import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/ui/core/ui/animated_reveal.dart';

void main() {
  late List<String> tapped;
  setUp(() => tapped = []);

  Widget banner(String label) => GestureDetector(
    onTap: () => tapped.add(label),
    child: SizedBox(height: 40, child: Text(label)),
  );

  Future<void> show(WidgetTester tester, Widget? child) => tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AnimatedReveal(child: child),
              const SizedBox(key: ValueKey('below'), height: 10),
            ],
          ),
        ),
      ),
    ),
  );

  // Where what sits under the reveal starts: the room it takes.
  double room(WidgetTester tester) =>
      tester.getTopLeft(find.byKey(const ValueKey('below'))).dy;

  testWidgets('grows in, then shrinks away still showing the last child', (
    tester,
  ) async {
    await show(tester, null);
    expect(room(tester), 0);

    await show(tester, banner('1 change'));
    expect(room(tester), 0, reason: 'starts closed');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    expect(room(tester), inExclusiveRange(0, 40));
    await tester.pumpAndSettle();
    expect(room(tester), 40);

    await show(tester, null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('1 change'), findsOneWidget, reason: 'still leaving');
    expect(room(tester), inExclusiveRange(0, 40));
    await tester.tap(find.text('1 change'), warnIfMissed: false);
    expect(tapped, isEmpty, reason: 'a leaving child takes no taps');

    await tester.pumpAndSettle();
    expect(find.text('1 change'), findsNothing);
    expect(room(tester), 0);
  });

  testWidgets('coming back mid-exit grows from where it is', (tester) async {
    await show(tester, banner('1 change'));
    await show(tester, null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final leaving = room(tester);

    await show(tester, banner('2 changes'));
    expect(room(tester), leaving, reason: 'no jump');
    expect(find.text('2 changes'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(room(tester), 40);
    await tester.tap(find.text('2 changes'));
    expect(tapped, ['2 changes']);
  });

  testWidgets('shown from the start, or updated, it stays put', (tester) async {
    await show(tester, banner('1 change'));
    expect(room(tester), 40);
    await show(tester, banner('2 changes'));
    expect(find.text('2 changes'), findsOneWidget);
    expect(room(tester), 40);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
