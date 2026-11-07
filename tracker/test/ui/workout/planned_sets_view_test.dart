import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/ui/workout/widgets/planned_sets_view.dart';

Future<void> _pump(WidgetTester tester, List<PlannedSet> sets) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) =>
          FTheme(data: FTheme.neutral.light.touch, child: child!),
      home: Scaffold(
        body: SizedBox(width: 200, child: PlannedSetsView(sets: sets)),
      ),
    ),
  );
}

void main() {
  group('PlannedSetsView', () {
    testWidgets('shows one tile per identical set', (tester) async {
      await _pump(tester, [
        for (var i = 0; i < 3; i++)
          PlannedSet(order: i, minReps: 8, maxReps: 12),
      ]);
      expect(find.text('8-12'), findsNWidgets(3));
      expect(find.text('reps'), findsNWidgets(3));
    });

    testWidgets('keeps mixed targets in plan order', (tester) async {
      await _pump(tester, [
        PlannedSet(order: 0, minReps: 10),
        PlannedSet(order: 1, minReps: 8, maxReps: 12),
      ]);
      final first = tester.getTopLeft(find.text('10'));
      final second = tester.getTopLeft(find.text('8-12'));
      expect(first.dx, lessThan(second.dx));
    });

    testWidgets('uses the singular unit for one rep', (tester) async {
      await _pump(tester, [PlannedSet(order: 0, minReps: 1)]);
      expect(find.text('rep'), findsOneWidget);
    });

    testWidgets('wraps many tiles without overflow', (tester) async {
      await _pump(tester, [
        for (var i = 0; i < 8; i++)
          PlannedSet(order: i, minReps: 10, maxReps: 15),
      ]);
      expect(find.text('10-15'), findsNWidgets(8));
      expect(tester.takeException(), isNull);
    });
  });
}
