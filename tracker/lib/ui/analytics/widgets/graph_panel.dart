import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/services/graph_series.dart';
import 'package:tracker/ui/analytics/widgets/graph_readout.dart';
import 'package:tracker/ui/core/ui/graph_chart.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';

/// A graph inside a page about something else: a small headline over the
/// chart, which reads the point tapped, dragged or hovered.
class GraphPanel extends StatefulWidget {
  const GraphPanel({super.key, required this.series, this.height = 180});

  final GraphSeries series;
  final double height;

  @override
  State<GraphPanel> createState() => _GraphPanelState();
}

class _GraphPanelState extends State<GraphPanel> {
  int? _read;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        GraphHeadlineView(
          headline: graphHeadline(context, widget.series, selected: _read),
          size: GraphHeadlineSize.inline,
        ),
        const SizedBox(height: 10),
        if (widget.series.isEmpty)
          SizedBox(
            height: widget.height,
            child: Center(
              child: Text(
                'Finish a workout to fill this graph.',
                style: theme.typography.body.sm.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ),
          )
        else
          GraphChart(
            series: widget.series,
            unit: weightUnitOf(context),
            height: widget.height,
            onSelect: (read) => setState(() => _read = read),
          ),
      ],
    );
  }
}
