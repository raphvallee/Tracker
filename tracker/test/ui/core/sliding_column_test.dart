import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/ui/core/ui/sliding_column.dart';

void main() {
  late List<String> tapped;
  setUp(() => tapped = []);

  Widget box(String label, double height) => GestureDetector(
    key: ValueKey(label),
    onTap: () => tapped.add(label),
    child: SizedBox(height: height, child: Text(label)),
  );

  Future<void> show(WidgetTester tester, List<Widget> children) =>
      tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 200,
              child: SlidingColumn(children: children),
            ),
          ),
        ),
      );

  double top(WidgetTester tester, String label) =>
      tester.getTopLeft(find.byKey(ValueKey(label))).dy;

  List<double> tops(WidgetTester tester, List<String> labels) => [
    for (final label in labels) top(tester, label),
  ];

  // Halfway through the slide's time.
  final half = Curves.easeInOutCubic.transform(0.5);

  testWidgets('children slide to their new places when the order changes', (
    tester,
  ) async {
    await show(tester, [box('A', 100), box('B', 50), box('C', 80)]);
    expect(tops(tester, ['A', 'B', 'C']), [0, 100, 150]);
    expect(tester.getSize(find.byType(SlidingColumn)), const Size(200, 230));

    // C moves to the top: everything starts where it was painted.
    await show(tester, [box('C', 80), box('A', 100), box('B', 50)]);
    expect(tops(tester, ['C', 'A', 'B']), [150, 0, 100]);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 210));
    expect(top(tester, 'C'), moreOrLessEquals(150 - 150 * half));
    expect(top(tester, 'A'), moreOrLessEquals(80 * half));
    expect(top(tester, 'B'), moreOrLessEquals(100 + 80 * half));

    // Mid-slide, C (moving up) passes over A: a tap where both are lands
    // on C.
    await tester.tapAt(const Offset(10, 100));
    expect(tapped, ['C']);

    await tester.pumpAndSettle();
    expect(tops(tester, ['C', 'A', 'B']), [0, 80, 180]);
  });

  testWidgets('a reorder mid-slide starts from where children are', (
    tester,
  ) async {
    await show(tester, [box('A', 100), box('B', 100)]);
    await show(tester, [box('B', 100), box('A', 100)]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 210));
    final midway = [
      moreOrLessEquals(100 * half),
      moreOrLessEquals(100 - 100 * half),
    ];
    expect(tops(tester, ['A', 'B']), midway);

    await show(tester, [box('A', 100), box('B', 100)]);
    expect(tops(tester, ['A', 'B']), midway, reason: 'no jump back');
    await tester.pumpAndSettle();
    expect(tops(tester, ['A', 'B']), [0, 100]);
  });

  testWidgets('arrivals take their place at once; the rest make room', (
    tester,
  ) async {
    await show(tester, [box('A', 100), box('B', 50)]);
    await show(tester, [box('N', 60), box('A', 100), box('B', 50)]);
    expect(tops(tester, ['N', 'A', 'B']), [0, 0, 100]);
    await tester.tapAt(const Offset(10, 30));
    expect(tapped, ['N'], reason: 'the arrival sits on top');
    await tester.pumpAndSettle();
    expect(tops(tester, ['N', 'A', 'B']), [0, 60, 160]);

    // Gone: the rest slide up into the gap.
    await show(tester, [box('N', 60), box('B', 50)]);
    expect(top(tester, 'B'), 160);
    await tester.pumpAndSettle();
    expect(top(tester, 'B'), 60);
  });

  testWidgets('the same order with new sizes moves at once', (tester) async {
    await show(tester, [box('A', 100), box('B', 50)]);
    await show(tester, [box('A', 120), box('B', 50)]);
    expect(top(tester, 'B'), 120);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
