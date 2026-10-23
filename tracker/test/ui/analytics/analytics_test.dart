// Analytics widget integration tests — DB-free chart/page smoke tests (no
// repository). The pure analytics math they render is unit-tested separately:
// test/unit/analytics_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/muscle.dart';
import 'package:tracker/domain/services/analytics.dart';
import 'package:tracker/ui/analytics/widgets/graph_editor.dart';
import 'package:tracker/ui/analytics/widgets/progression_page.dart';
import 'package:tracker/ui/core/ui/line_chart.dart';
import 'package:tracker/ui/exercises/widgets/exercise_detail_page.dart';

import '../../../testing/test_helpers.dart';

void main() {
  group('analytics widgets (DB-free)', () {
    testWidgets('LineChart renders an empty state', (tester) async {
      await pumpAppPage(
        tester,
        Scaffold(body: LineChart(points: const <ProgressionPoint>[])),
      );
      expect(find.text('No data yet'), findsOneWidget);
    });

    testWidgets('LineChart renders a series without crashing', (tester) async {
      await pumpAppPage(
        tester,
        Scaffold(
          body: LineChart(
            points: [
              ProgressionPoint(date: DateTime(2026, 1, 1), value: 10),
              ProgressionPoint(date: DateTime(2026, 1, 2), value: 20),
            ],
          ),
        ),
      );
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('ExerciseDetailPage builds and shows an empty chart', (
      tester,
    ) async {
      await pumpAppPage(
        tester,
        ExerciseDetailPage(
          exercise: Exercise(
            title: 'Bench Press',
            primaryMuscle: [Muscle.chest],
            equipment: [Equipment.barbell],
            movementPattern: MovementPattern.push,
          ),
        ),
      );

      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('Best 1RM'), findsOneWidget);
      expect(find.text('No data yet'), findsOneWidget);
    });

    testWidgets('ProgressionPage opens without a repository', (tester) async {
      await pumpAppPage(tester, const ProgressionPage());
      expect(find.text('Working volume over time'), findsOneWidget);
      expect(find.text('No data yet'), findsNWidgets(2));
    });

    testWidgets('graph editor flags an empty title inline', (tester) async {
      await pumpAppPage(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => GraphEditor.show(context, exercises: const []),
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      expect(find.text('Add graph'), findsOneWidget);

      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      // Invoke the button directly: the sheet's Save button can sit outside
      // the test viewport, where tap() cannot reach it.
      tester
          .widget<FButton>(
            find.ancestor(
              of: find.text('Save'),
              matching: find.byType(FButton),
            ),
          )
          .onPress!();
      // FTextField publishes its error variant through a post-frame callback,
      // so give it a couple of frames plus its expand animation.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Cannot be empty'), findsOneWidget);
      // The sheet stays open instead of silently doing nothing.
      expect(find.text('Add graph'), findsOneWidget);
    });
  });
}
