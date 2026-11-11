import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/graph_config.dart';
import 'package:tracker/ui/analytics/widgets/graph_readout.dart';

/// 1M, 3M, 1Y, All in one muted track; the picked one sits raised on it,
/// and slides over when another is picked.
class GraphRangeControl extends StatelessWidget {
  const GraphRangeControl({
    super.key,
    required this.value,
    required this.onChange,
  });

  final GraphTimeframe value;
  final ValueChanged<GraphTimeframe> onChange;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final index = graphRanges.indexOf(value);
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colors.muted,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Stack(
        children: <Widget>[
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment(-1 + 2 * index / (graphRanges.length - 1), 0),
            child: FractionallySizedBox(
              widthFactor: 1 / graphRanges.length,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  // Raised: the page's white in light mode, a lighter step
                  // of the track in dark mode (the page's black would sink).
                  color: theme.colors.brightness == Brightness.dark
                      ? Color.alphaBlend(
                          theme.colors.foreground.withValues(alpha: 0.1),
                          theme.colors.muted,
                        )
                      : theme.colors.background,
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: <Widget>[
              for (final range in graphRanges)
                Expanded(
                  child: FTappable(
                    semanticsLabel: switch (range) {
                      GraphTimeframe.last30Days => 'Last month',
                      GraphTimeframe.last90Days => 'Last 3 months',
                      GraphTimeframe.lastYear => 'Last year',
                      GraphTimeframe.all => 'All time',
                    },
                    selected: range == value,
                    onPress: () {
                      if (range != value) onChange(range);
                    },
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 150),
                        style: theme.typography.body.sm.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: range == value
                              ? theme.colors.foreground
                              : theme.colors.mutedForeground,
                        ),
                        child: Text(graphRangeLabel(range)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
