import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/graph_config.dart';
import 'package:tracker/domain/models/muscle.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/services/graph_series.dart';
import 'package:tracker/ui/analytics/widgets/graph_tile.dart';
import 'package:tracker/ui/core/ui/graph_chart.dart';
import 'package:tracker/ui/core/ui/motion.dart';

import '../../../testing/test_helpers.dart';

final _bench = Exercise(
  title: 'Bench Press',
  primaryMuscle: [Muscle.triceps],
  equipment: [Equipment.barbell],
)..id = 7;

final _now = DateTime(2026, 11, 16, 20);

/// A bench session every five days for fourteen months, slowly climbing.
final _history = [
  for (var i = 0; i < 85; i++)
    WorkoutSession(
      title: 'Push Day',
      startTime: DateTime(_now.year, _now.month - 14, _now.day + 5 * i, 18),
      sets: [
        WorkoutSet(
          exerciseId: _bench.id,
          weight: 80 + i * 0.3 + (i % 4) * 2,
          reps: 5 + i % 3,
        ),
      ],
    )..id = i + 1,
];

GraphSeries _series(GraphMetric metric, GraphTimeframe range) => graphSeries(
  sessions: _history,
  exerciseId: _bench.id,
  metric: metric,
  range: range,
  now: _now,
);

/// A chart whose range the test sets.
class _Host extends StatefulWidget {
  const _Host({super.key, required this.metric, required this.onSelect});

  final GraphMetric metric;
  final ValueChanged<int?> onSelect;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  GraphTimeframe range = GraphTimeframe.last30Days;

  void show(GraphTimeframe next) => setState(() => range = next);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: GraphChart(
      series: _series(widget.metric, range),
      unit: WeightUnit.kilograms,
      height: 220,
      onSelect: widget.onSelect,
    ),
  );
}

void main() {
  for (final metric in GraphMetric.values) {
    testWidgets('${metric.name}: a new range moves the chart there, and a '
        'point is read only once it has arrived', (tester) async {
      final key = GlobalKey<_HostState>();
      final read = <int?>[];
      await pumpAppPage(
        tester,
        Scaffold(
          body: _Host(key: key, metric: metric, onSelect: read.add),
        ),
      );
      final chart = tester.getRect(find.byType(GraphChart));

      // Wider, then mid-move a tap reads nothing.
      key.currentState!.show(GraphTimeframe.last90Days);
      await tester.pump();
      await tester.pump(Motion.roomIn ~/ 3);
      await tester.tapAt(chart.center);
      await tester.pump();
      expect(read, isEmpty);
      await tester.pumpAndSettle();

      // Wider again, weeks to months for volume, then picked again
      // mid-move and narrowed: every frame paints.
      key.currentState!.show(GraphTimeframe.lastYear);
      await tester.pump();
      await tester.pump(Motion.roomIn ~/ 2);
      key.currentState!.show(GraphTimeframe.last30Days);
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pumpAndSettle();

      // At rest a tap reads the nearest point.
      await tester.tapAt(chart.center);
      await tester.pump();
      expect(read, isNotEmpty);
      expect(read.last, isNotNull);
    });
  }

  testWidgets('with reduced motion a new range is there at once', (
    tester,
  ) async {
    final key = GlobalKey<_HostState>();
    final read = <int?>[];
    await pumpAppPage(
      tester,
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(
          body: _Host(
            key: key,
            metric: GraphMetric.best1rm,
            onSelect: read.add,
          ),
        ),
      ),
    );
    key.currentState!.show(GraphTimeframe.all);
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    await tester.tapAt(tester.getRect(find.byType(GraphChart)).center);
    await tester.pump();
    expect(read.last, isNotNull);
  });

  testWidgets('a tile crossfades its note to the new range, once', (
    tester,
  ) async {
    var range = GraphTimeframe.last30Days;
    late StateSetter setRange;
    await pumpAppPage(
      tester,
      Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            setRange = setState;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: GraphGrid(
                onAdd: () {},
                tiles: [
                  GraphTile(
                    name: 'Bench Press',
                    series: _series(GraphMetric.best1rm, range),
                    onPress: () {},
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    expect(find.text('· 1M'), findsOneWidget);

    setRange(() => range = GraphTimeframe.last90Days);
    await tester.pump();
    await tester.pump(Motion.roomIn ~/ 2);
    // Halfway: the old note on its way out under the new one.
    expect(find.text('· 1M'), findsOneWidget);
    expect(find.text('· 3M'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('· 1M'), findsNothing);
    expect(find.text('· 3M'), findsOneWidget);
  });
}
