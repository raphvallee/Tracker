import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/services/workout_dates.dart';
import 'package:tracker/ui/history/widgets/calendar/history_calendar.dart';

import '../../../testing/test_helpers.dart';

void main() {
  Future<void> pumpCalendar(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      builder: (context, child) =>
          FTheme(data: FTheme.neutral.light.touch, child: child!),
      home: Scaffold(
        body: SingleChildScrollView(
          child: HistoryCalendar(
            index: WorkoutDateIndex(const []),
            onPickDay: (_) {},
          ),
        ),
      ),
    ),
  );

  Future<void> swipe(WidgetTester tester, Offset by) async {
    await tester.fling(find.byType(HistoryCalendar), by, 1000);
    await tester.pumpAndSettle();
  }

  String monthTitle(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data ?? '')
      .firstWhere((text) => RegExp(r'^[A-Z][a-z]+ \d{4}$').hasMatch(text));

  testWidgets('a swipe turns the month, left for next and right for previous', (
    tester,
  ) async {
    await pumpCalendar(tester);
    final start = monthTitle(tester);

    await swipe(tester, const Offset(-300, 0));
    final next = monthTitle(tester);
    expect(next, isNot(start));

    await swipe(tester, const Offset(300, 0));
    expect(monthTitle(tester), start);

    await swipe(tester, const Offset(300, 0));
    final previous = monthTitle(tester);
    expect(previous, isNot(start));
    expect(previous, isNot(next));
  });

  testWidgets('the months follow the finger and snap to one', (tester) async {
    await pumpCalendar(tester);
    final pages = tester.widget<PageView>(find.byType(PageView)).controller!;
    final start = pages.page!;

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PageView)),
    );
    await gesture.moveBy(const Offset(-120, 0));
    await tester.pump();
    expect(pages.page, greaterThan(start));
    expect(pages.page, lessThan(start + 1));

    // Past the middle of the month, letting go snaps to the next one.
    await gesture.moveBy(const Offset(-400, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(pages.page, start + 1);
  });

  testWidgets('the month name and the weekdays travel with the month', (
    tester,
  ) async {
    await pumpCalendar(tester);
    final names = RegExp(r'^[A-Z][a-z]+ \d{4}$');
    int monthNames() => tester
        .widgetList<Text>(find.byType(Text))
        .where((text) => names.hasMatch(text.data ?? ''))
        .length;

    expect(monthNames(), 1);
    expect(find.text('W'), findsOneWidget);

    // Dragged part way, both months are in view, each with its own name and
    // its own row of weekdays.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PageView)),
    );
    await gesture.moveBy(const Offset(-300, 0));
    await tester.pump();
    expect(monthNames(), 2);
    expect(find.text('W'), findsNWidgets(2));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(monthNames(), 1);
  });

  final back = find.byKey(const ValueKey('this-month'));

  double backOpacity(WidgetTester tester) => tester
      .widget<Opacity>(
        find.descendant(of: back, matching: find.byType(Opacity)),
      )
      .opacity;

  Finder arrow(IconData icon) => find.descendant(
    of: back,
    matching: find.byWidgetPredicate((w) => w is Icon && w.icon == icon),
  );

  const forward = Offset(-300, 0);

  testWidgets('away from this month, the way back brings it back', (
    tester,
  ) async {
    await pumpCalendar(tester);
    final start = monthTitle(tester);
    expect(backOpacity(tester), 0);

    for (var i = 0; i < 3; i++) {
      await swipe(tester, forward);
    }
    expect(monthTitle(tester), isNot(start));
    expect(backOpacity(tester), 1);

    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(monthTitle(tester), start);
    expect(backOpacity(tester), 0);
  });

  testWidgets('on this month, the way back takes no taps', (tester) async {
    await pumpCalendar(tester);
    final start = monthTitle(tester);
    await tester.tap(back, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(monthTitle(tester), start);
    expect(find.bySemanticsLabel('This month'), findsNothing);
  });

  testWidgets('the way back follows the finger, not a timer', (tester) async {
    await pumpCalendar(tester);
    await tester.pumpAndSettle();
    final place = tester.getCenter(back);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PageView)),
    );

    // A quarter of the way to the next month, it is a quarter of the way in,
    // and stays so for as long as the finger holds still.
    final width = tester.getSize(find.byType(PageView)).width * 1.07;
    await gesture.moveBy(Offset(-width / 4, 0));
    await tester.pump();
    final quarter = backOpacity(tester);
    expect(quarter, closeTo(0.25, 0.05));
    await tester.pump(const Duration(seconds: 1));
    expect(backOpacity(tester), quarter);

    // Dragged back, it goes again, in the same place.
    await gesture.moveBy(Offset(width / 4, 0));
    await tester.pump();
    expect(backOpacity(tester), closeTo(0, 0.01));
    expect(tester.getCenter(back), place);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('its arrow is on the side of this month and points to it', (
    tester,
  ) async {
    await pumpCalendar(tester);

    await swipe(tester, forward);
    expect(arrow(FLucideIcons.chevronLeft), findsOneWidget);
    expect(arrow(FLucideIcons.chevronRight), findsNothing);
    final icon = arrow(FLucideIcons.calendarCheck);
    expect(
      tester.getCenter(arrow(FLucideIcons.chevronLeft)).dx,
      lessThan(tester.getCenter(icon).dx),
    );

    await swipe(tester, -forward);
    await swipe(tester, -forward);
    expect(arrow(FLucideIcons.chevronRight), findsOneWidget);
    expect(arrow(FLucideIcons.chevronLeft), findsNothing);
    expect(
      tester.getCenter(arrow(FLucideIcons.chevronRight)).dx,
      greaterThan(tester.getCenter(icon).dx),
    );
  });

  testWidgets('the workout days ride with the month, the streak stays', (
    tester,
  ) async {
    await pumpCalendar(tester);
    expect(find.text('No workout days'), findsOneWidget);
    expect(find.text('No streak right now'), findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PageView)),
    );
    await gesture.moveBy(const Offset(-300, 0));
    await tester.pump();
    expect(find.text('No workout days'), findsNWidgets(2));
    expect(find.text('No streak right now'), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('the arrows are gone', (tester) async {
    await pumpCalendar(tester);
    await tester.pumpAndSettle();
    expect(fButtonByTooltip('Next month'), findsNothing);
    expect(fButtonByTooltip('Previous month'), findsNothing);
  });

  testWidgets('the sheet keeps its height from month to month', (tester) async {
    await pumpCalendar(tester);
    final height = tester.getSize(find.byType(HistoryCalendar)).height;

    // Twelve months cover every number of weeks a month can span, February
    // with four included.
    for (var i = 0; i < 12; i++) {
      await swipe(tester, forward);
      expect(tester.getSize(find.byType(HistoryCalendar)).height, height);
    }
  });
}
