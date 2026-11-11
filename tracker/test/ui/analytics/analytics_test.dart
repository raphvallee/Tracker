import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/graph_config.dart';
import 'package:tracker/domain/models/muscle.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/services/graph_series.dart';
import 'package:tracker/ui/analytics/view_models/analytics_data.dart';
import 'package:tracker/ui/analytics/widgets/graph_editor.dart';
import 'package:tracker/ui/analytics/widgets/graph_page.dart';
import 'package:tracker/ui/analytics/widgets/graph_panel.dart';
import 'package:tracker/ui/analytics/widgets/graph_tile.dart';
import 'package:tracker/ui/core/ui/graph_chart.dart';
import 'package:tracker/ui/core/ui/relative_dates.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';

import '../../../testing/test_helpers.dart';

final _bench = Exercise(
  title: 'Bench Press',
  primaryMuscle: [Muscle.triceps],
  equipment: [Equipment.barbell],
)..id = 7;

/// Bench sessions over the last weeks, each a day apart from the next by
/// a week: 100, 110 (a PR), 105, then the newest, 108.
List<WorkoutSession> _sessions(DateTime now) => [
  for (final (i, weight) in [100.0, 110.0, 105.0, 108.0].indexed)
    WorkoutSession(
      title: 'Push Day',
      startTime: DateTime(now.year, now.month, now.day - 21 + 7 * i, 18),
      sets: [
        WorkoutSet(
          exerciseId: _bench.id,
          weight: 60,
          reps: 10,
          type: SetType.warmup,
        ),
        WorkoutSet(exerciseId: _bench.id, weight: weight, reps: 1),
      ],
    )..id = i + 1,
];

GraphSeries _series(GraphMetric metric, {DateTime? now}) {
  final at = now ?? DateTime.now();
  return graphSeries(
    sessions: _sessions(at),
    exerciseId: _bench.id,
    metric: metric,
    range: GraphTimeframe.last90Days,
    now: at,
  );
}

void main() {
  group('graph widgets (DB-free)', () {
    testWidgets('a tap reads the nearest session; tapping it again puts it '
        'away', (tester) async {
      final series = _series(GraphMetric.best1rm);
      await pumpAppPage(
        tester,
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: GraphPanel(series: series),
          ),
        ),
      );
      // At rest: the newest session and how far it moved.
      expect(find.text('108 kg'), findsOneWidget);
      expect(find.text('in 3 months'), findsOneWidget);

      final chart = tester.getRect(find.byType(GraphChart));
      final first = shortDateLabel(series.sessions.first.date);
      await tester.tapAt(Offset(chart.left + 6, chart.center.dy));
      await tester.pumpAndSettle();
      expect(find.text('100 kg'), findsOneWidget);
      expect(find.text('$first · Push Day'), findsOneWidget);

      await tester.tapAt(Offset(chart.left + 6, chart.center.dy));
      await tester.pumpAndSettle();
      expect(find.text('108 kg'), findsOneWidget);
      expect(find.text('$first · Push Day'), findsNothing);
    });

    testWidgets('dragging reads a PR with its tag', (tester) async {
      final series = _series(GraphMetric.record1rm);
      await pumpAppPage(
        tester,
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: GraphPanel(series: series),
          ),
        ),
      );
      // At rest a record graph reads the best ever, 110.
      expect(find.text('110 kg'), findsOneWidget);
      expect(find.text('PR'), findsNothing);

      final chart = tester.getRect(find.byType(GraphChart));
      double x(int i) => GraphChartProbe.xOf(tester, series, i);
      final gesture = await tester.startGesture(
        Offset(chart.left + x(0), chart.center.dy),
      );
      await gesture.moveBy(const Offset(12, 0));
      await gesture.moveTo(Offset(chart.left + x(1), chart.center.dy));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('110 kg'), findsOneWidget);
      expect(find.text('PR'), findsOneWidget);
    });

    testWidgets('a tile leads with its exercise, measure and value, and '
        'opens on tap', (tester) async {
      var opened = 0;
      await pumpAppPage(
        tester,
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: GraphGrid(
              onAdd: () {},
              tiles: [
                GraphTile(
                  name: 'Bench Press',
                  series: _series(GraphMetric.best1rm),
                  onPress: () => opened++,
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('Est. 1RM'), findsOneWidget);
      expect(find.text('108 kg'), findsOneWidget);
      expect(find.text('8 kg '), findsOneWidget);
      expect(find.text('· 3M'), findsOneWidget);
      expect(find.text('Add graph'), findsOneWidget);

      await tester.tap(find.text('Bench Press'));
      await tester.pumpAndSettle();
      expect(opened, 1);
    });

    testWidgets('the sheet asks for an exercise before adding a graph', (
      tester,
    ) async {
      await pumpAppPage(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => GraphEditor.show(context, exercises: [_bench]),
                child: const Text('Open sheet'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Pick one'), findsOneWidget);
      expect(find.text('1RM PR'), findsOneWidget);

      tester
          .widget<FButton>(
            find.ancestor(
              of: find.text('Add graph').last,
              matching: find.byType(FButton),
            ),
          )
          .onPress!();
      await tester.pumpAndSettle();
      expect(find.text('Pick the exercise to graph'), findsOneWidget);

      await tester.tap(find.text('Exercise'));
      await tester.pumpAndSettle();
      expect(find.text('Select exercise'), findsOneWidget);
      expect(find.text('All exercises'), findsNothing);
    });

    testWidgets('editing a graph changes its measure', (tester) async {
      GraphConfig? saved;
      await pumpAppPage(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async => saved = await GraphEditor.show(
                  context,
                  initial: GraphConfig(exerciseId: _bench.id),
                  exercises: [_bench],
                ),
                child: const Text('Open sheet'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Edit graph'), findsOneWidget);
      expect(find.text('Bench Press'), findsOneWidget);

      await tester.tap(find.text('1RM PR'));
      await tester.pumpAndSettle();
      tester
          .widget<FButton>(
            find.ancestor(
              of: find.text('Save'),
              matching: find.byType(FButton),
            ),
          )
          .onPress!();
      await tester.pumpAndSettle();
      expect(
        saved,
        GraphConfig(exerciseId: _bench.id, metric: GraphMetric.record1rm),
      );
    });

    testWidgets('the graph page lists its sessions and shares its range', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpApp(tester);
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      final settings = SettingsCubit.maybeOf(navigator.context)!
        ..addGraph(
          GraphConfig(exerciseId: _bench.id, metric: GraphMetric.record1rm),
        );
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => GraphPage(
              index: 0,
              data: AnalyticsData(
                sessions: _sessions(DateTime.now()),
                exercises: [_bench],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('1RM PR'), findsOneWidget);
      expect(find.text('Sessions'), findsOneWidget);
      expect(find.text('4 in 3 months'), findsOneWidget);
      // The first session and the 110 are records.
      expect(find.text('PR'), findsNWidgets(2));
      expect(find.text('110 kg × 1'), findsOneWidget);

      await tester.tap(find.text('1Y'));
      await tester.pumpAndSettle();
      expect(settings.state.graphRange, GraphTimeframe.lastYear);
      expect(find.text('4 in 1 year'), findsOneWidget);
    });
  });
}

/// Where the chart puts a session across, worked out the way it does.
abstract final class GraphChartProbe {
  static double xOf(WidgetTester tester, GraphSeries series, int i) {
    final width = tester.getSize(find.byType(GraphChart)).width;
    // Mirrors the chart: the plot leaves a gutter for the value labels,
    // and the line keeps 4 px in from its left and 6 px from its right.
    const gutter = 32.0;
    final span = series.to.difference(series.from).inMilliseconds;
    final t = series.sessions[i].date.difference(series.from).inMilliseconds;
    return 4 + (width - gutter - 10) * t / span;
  }
}
