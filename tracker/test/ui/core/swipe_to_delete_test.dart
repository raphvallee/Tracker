import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/ui/core/ui/swipe_to_delete.dart';

void main() {
  late int deleted;
  late int tapped;
  setUp(() {
    deleted = 0;
    tapped = 0;
  });

  Future<void> show(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      home: FTheme(
        data: FTheme.neutral.light.touch,
        child: Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 300, child: child),
          ),
        ),
      ),
    ),
  );

  Future<void> swipe(WidgetTester tester, Finder target, double dx) async {
    await tester.timedDrag(
      target,
      Offset(dx, 0),
      const Duration(milliseconds: 250),
    );
    await tester.pumpAndSettle();
  }

  group('SwipeToDelete', () {
    Widget row({bool canDelete = true}) => SwipeToDelete(
      canDelete: canDelete,
      onDelete: () => deleted++,
      child: GestureDetector(
        onTap: () => tapped++,
        child: const SizedBox(height: 56, child: Text('Row')),
      ),
    );

    double offset(WidgetTester tester) =>
        tester.getTopLeft(find.text('Row')).dx;

    testWidgets('one swipe opens on Delete, a second one deletes', (
      tester,
    ) async {
      await show(tester, row());
      await swipe(tester, find.text('Row'), -280);
      expect(deleted, 0, reason: 'one swipe never deletes');
      expect(offset(tester), -SwipeToDelete.actionWidth);
      expect(find.text('Delete'), findsOneWidget);

      await swipe(tester, find.text('Row'), -200);
      expect(deleted, 1);
    });

    testWidgets('open, a tap on the row closes it; Delete deletes', (
      tester,
    ) async {
      await show(tester, row());
      await swipe(tester, find.text('Row'), -120);
      await tester.tap(find.text('Row'));
      await tester.pumpAndSettle();
      expect(offset(tester), 0);
      expect(tapped, 0, reason: 'the tap only closed it');

      await swipe(tester, find.text('Row'), -120);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(deleted, 1);
    });

    testWidgets('a short swipe or a swipe back right closes it', (
      tester,
    ) async {
      await show(tester, row());
      await swipe(tester, find.text('Row'), -30);
      expect(offset(tester), 0);
      await swipe(tester, find.text('Row'), -120);
      await swipe(tester, find.text('Row'), 120);
      expect(offset(tester), 0);
      expect(deleted, 0);
    });

    testWidgets('a row that cannot go only gives a little', (tester) async {
      await show(tester, row(canDelete: false));
      await swipe(tester, find.text('Row'), -280);
      await swipe(tester, find.text('Row'), -280);
      expect(offset(tester), 0);
      expect(find.text('Delete'), findsNothing);
      expect(deleted, 0);
    });
  });

  group('SwipeToDeleteChip', () {
    Widget chip({bool canDelete = true}) => SizedBox(
      width: 56,
      height: 42,
      child: SwipeToDeleteChip(
        canDelete: canDelete,
        onDelete: () => deleted++,
        child: GestureDetector(
          onTap: () => tapped++,
          child: const ColoredBox(
            color: Color(0xFFEEEEEE),
            child: Center(child: Text('8')),
          ),
        ),
      ),
    );

    Finder trash() => find.byIcon(FLucideIcons.trash2);

    testWidgets('one swipe arms it, a second one deletes', (tester) async {
      await show(tester, chip());
      await swipe(tester, find.text('8'), -60);
      expect(trash(), findsOneWidget);
      expect(deleted, 0, reason: 'one swipe never deletes');

      await swipe(tester, find.text('8'), -60);
      expect(deleted, 1);
    });

    testWidgets('armed, a tap turns it back without opening it', (
      tester,
    ) async {
      await show(tester, chip());
      await swipe(tester, find.text('8'), -60);
      await tester.tap(find.text('8'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(trash(), findsNothing);
      expect(tapped, 0);

      await tester.tap(find.text('8'));
      expect(tapped, 1, reason: 'disarmed, a tap opens it again');
    });

    testWidgets('a chip that cannot go never arms', (tester) async {
      await show(tester, chip(canDelete: false));
      await swipe(tester, find.text('8'), -60);
      await swipe(tester, find.text('8'), -60);
      expect(trash(), findsNothing);
      expect(deleted, 0);
    });
  });

  testWidgets('a chip inside a row keeps the swipes that start on it', (
    tester,
  ) async {
    var rowDeleted = 0;
    var chipDeleted = 0;
    await show(
      tester,
      SwipeToDelete(
        canDelete: true,
        onDelete: () => rowDeleted++,
        padding: const EdgeInsets.only(bottom: 8),
        child: SizedBox(
          height: 100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 40, child: Text('Row')),
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 56,
                  height: 42,
                  child: SwipeToDeleteChip(
                    canDelete: true,
                    onDelete: () => chipDeleted++,
                    child: const ColoredBox(
                      color: Color(0xFFEEEEEE),
                      child: Center(child: Text('8')),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    double offset() => tester.getTopLeft(find.text('Row')).dx;
    double height() => tester.getSize(find.byType(SwipeToDelete)).height;
    expect(height(), 108, reason: 'the row and its gap');

    // On the chip: the chip arms, then goes; the row never moves.
    await swipe(tester, find.text('8'), -60);
    expect(find.byIcon(FLucideIcons.trash2), findsOneWidget);
    expect(offset(), 0);
    expect(find.text('Delete'), findsNothing);
    await swipe(tester, find.text('8'), -60);
    expect(chipDeleted, 1);
    expect(rowDeleted, 0);
    expect(offset(), 0);

    // Anywhere else: the row opens, then goes whole, its gap folding away
    // with it.
    await swipe(tester, find.text('Row'), -120);
    expect(offset(), -SwipeToDelete.actionWidth);
    expect(rowDeleted, 0);
    await swipe(tester, find.text('Row'), -250);
    expect(rowDeleted, 1);
    expect(height(), 0);
  });
}
