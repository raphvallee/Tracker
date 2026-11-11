import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/services/graph_series.dart';
import 'package:tracker/ui/analytics/widgets/graph_readout.dart';
import 'package:tracker/ui/core/ui/dashed_outline.dart';
import 'package:tracker/ui/core/ui/graph_chart.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';

/// The Feed's graphs, half a screen wide each on a phone (more across on a
/// wide window), then a dashed tile that adds one. Tiles in a row share
/// their height.
class GraphGrid extends StatelessWidget {
  const GraphGrid({super.key, required this.tiles, required this.onAdd});

  final List<Widget> tiles;
  final VoidCallback onAdd;

  static const double _gap = 10;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return _AddGraphTile(onPress: onAdd, wide: true);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 190).floor().clamp(2, 4);
        final cells = [...tiles, _AddGraphTile(onPress: onAdd)];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (var row = 0; row < cells.length; row += columns) ...[
              if (row > 0) const SizedBox(height: _gap),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (var i = row; i < row + columns; i++) ...[
                      if (i > row) const SizedBox(width: _gap),
                      Expanded(
                        child: i < cells.length
                            ? cells[i]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// One graph on the Feed: the exercise, what is measured, the headline
/// and a sparkline. A tap opens the graph; hovering reads a point.
class GraphTile extends StatefulWidget {
  const GraphTile({
    super.key,
    required this.name,
    required this.series,
    required this.onPress,
  });

  final String name;
  final GraphSeries series;
  final VoidCallback onPress;

  @override
  State<GraphTile> createState() => _GraphTileState();
}

class _GraphTileState extends State<GraphTile> {
  int? _read;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final series = widget.series;
    return FTappable(
      onPress: widget.onPress,
      builder: (context, states, child) => AnimatedOpacity(
        duration: const Duration(milliseconds: 100),
        opacity: states.contains(FTappableVariant.pressed) ? 0.75 : 1,
        child: child,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
        decoration: BoxDecoration(
          color: theme.colors.card,
          border: Border.all(color: theme.colors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.body.sm.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
            Text(
              graphMetricShortLabel(series.metric),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
            const SizedBox(height: 8),
            GraphHeadlineView(
              headline: graphHeadline(
                context,
                series,
                selected: _read,
                short: true,
              ),
              size: GraphHeadlineSize.tile,
            ),
            const Spacer(),
            const SizedBox(height: 8),
            GraphChart(
              series: series,
              unit: weightUnitOf(context),
              height: 40,
              compact: true,
              input: GraphInput.hover,
              surface: theme.colors.card,
              onSelect: (read) => setState(() => _read = read),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddGraphTile extends StatelessWidget {
  const _AddGraphTile({required this.onPress, this.wide = false});

  final VoidCallback onPress;

  /// Alone, with a line on what a graph is, when there are none yet.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return FTappable(
      onPress: onPress,
      builder: (context, states, child) => AnimatedOpacity(
        duration: const Duration(milliseconds: 100),
        opacity: states.contains(FTappableVariant.pressed) ? 0.6 : 1,
        child: child,
      ),
      child: CustomPaint(
        painter: DashedOutline(
          color: theme.colors.border,
          radius: 12,
          width: 1.5,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: wide ? 20 : 12,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(FLucideIcons.plus, size: 20),
              const SizedBox(height: 6),
              Text(
                'Add graph',
                style: theme.typography.body.sm.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (wide) ...[
                const SizedBox(height: 2),
                Text(
                  "Follow one exercise's 1RM, PRs, heaviest weight or volume",
                  textAlign: TextAlign.center,
                  style: theme.typography.body.xs.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
