import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/graph_config.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/domain/services/graph_series.dart';
import 'package:tracker/ui/core/ui/relative_dates.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';

/// The ranges in the order the range control offers them.
const graphRanges = [
  GraphTimeframe.last30Days,
  GraphTimeframe.last90Days,
  GraphTimeframe.lastYear,
  GraphTimeframe.all,
];

/// The measures in the order the graph sheet offers them.
const graphMetrics = [
  GraphMetric.best1rm,
  GraphMetric.record1rm,
  GraphMetric.peakWeight,
  GraphMetric.volume,
];

String graphRangeLabel(GraphTimeframe range) => switch (range) {
  GraphTimeframe.last30Days => '1M',
  GraphTimeframe.last90Days => '3M',
  GraphTimeframe.lastYear => '1Y',
  GraphTimeframe.all => 'All',
};

String graphMetricLabel(GraphMetric metric) => switch (metric) {
  GraphMetric.best1rm => 'Estimated 1RM',
  GraphMetric.record1rm => '1RM PR',
  GraphMetric.peakWeight => 'Heaviest weight',
  GraphMetric.volume => 'Volume',
};

String graphMetricShortLabel(GraphMetric metric) => switch (metric) {
  GraphMetric.best1rm => 'Est. 1RM',
  GraphMetric.record1rm => '1RM PR',
  GraphMetric.peakWeight => 'Heaviest',
  GraphMetric.volume => 'Volume',
};

String graphMetricDescription(GraphMetric metric) => switch (metric) {
  GraphMetric.best1rm => 'Your best set each session, worked out to one rep',
  GraphMetric.record1rm => 'Your best 1RM ever. It only climbs on a new PR',
  GraphMetric.peakWeight => 'The most weight on the bar each session, any reps',
  GraphMetric.volume => 'Weight × reps of every working set, by week or month',
};

/// "in 3 months", or "since Oct 2025" for all time.
String graphRangeWords(GraphSeries series) => switch (series.range) {
  GraphTimeframe.last30Days => 'in 1 month',
  GraphTimeframe.last90Days => 'in 3 months',
  GraphTimeframe.lastYear => 'in 1 year',
  GraphTimeframe.all =>
    'since ${shortMonthName(series.from.month)} ${series.from.year}',
};

/// "Week of 2 Nov", "October 2025"; the running one "so far".
String graphBucketLabel(GraphBucket bucket, GraphPeriod period) =>
    switch (period) {
      GraphPeriod.week =>
        bucket.isCurrent
            ? 'This week so far'
            : 'Week of ${dayMonthLabel(bucket.start)}',
      GraphPeriod.month =>
        bucket.isCurrent
            ? 'This month so far'
            : monthLabel(bucket.start.year, bucket.start.month),
    };

/// A graph value in the unit shown: kilograms to one decimal, volume
/// rounded and grouped ("21,216").
String graphNumber(BuildContext context, GraphMetric metric, double kilograms) {
  final shown = displayWeightOf(context, kilograms);
  if (metric == GraphMetric.volume) return groupedNumber(shown);
  return formatDecimal((shown * 10).round() / 10);
}

/// What a graph's headline says: a value, and under it either how far the
/// value moved (with an arrow) or a note.
class GraphHeadline {
  const GraphHeadline({
    this.value,
    this.change,
    required this.note,
    this.isRecord = false,
  });

  /// The number, without its unit; null when there is nothing to show.
  final String? value;

  /// How far the value moved in the range, in the unit shown, signed.
  final double? change;

  /// After [change], or alone when there is none.
  final String note;

  /// The value read is a PR.
  final bool isRecord;
}

/// The headline of [series]: the point [selected] while one is read, else
/// the newest value and how far it moved. [short] words it for a tile.
GraphHeadline graphHeadline(
  BuildContext context,
  GraphSeries series, {
  int? selected,
  bool short = false,
}) {
  String number(double kilograms) =>
      graphNumber(context, series.metric, kilograms);
  final range = short
      ? '· ${graphRangeLabel(series.range)}'
      : graphRangeWords(series);
  final points = series.metric == GraphMetric.volume
      ? series.buckets.length
      : series.sessions.length;
  // A point read on the series before (another range) may not exist here.
  final read = selected != null && selected < points ? selected : null;
  if (read != null) {
    if (series.metric == GraphMetric.volume) {
      final bucket = series.buckets[read];
      final label = graphBucketLabel(bucket, series.period!);
      return GraphHeadline(
        value: number(bucket.value),
        note: short ? label : '$label · ${plural('workout', bucket.sessions)}',
      );
    }
    final session = series.sessions[read];
    final date = shortDateLabel(session.date);
    return GraphHeadline(
      value: number(session.value),
      note: short ? date : '$date · ${session.title}',
      isRecord: session.isRecord,
    );
  }
  final latest = series.latest;
  if (latest == null) {
    // Read after "No sessions".
    return GraphHeadline(
      note: series.range == GraphTimeframe.all
          ? 'yet'
          : graphRangeWords(series),
    );
  }
  if (series.metric == GraphMetric.volume) {
    final bucket = series.headlineBucket!;
    final label = graphBucketLabel(bucket, series.period!);
    final average = series.average;
    return GraphHeadline(
      value: number(latest),
      note: short || average == null
          ? label
          : '$label · average ${formatVolume(context, average)}',
    );
  }
  final change = series.change;
  if (change == null) {
    final last = series.sessions.last;
    return GraphHeadline(
      value: number(latest),
      note: shortDateLabel(last.date),
      isRecord: series.metric == GraphMetric.record1rm,
    );
  }
  if (series.metric == GraphMetric.record1rm && change == 0) {
    return GraphHeadline(value: number(latest), note: 'No new PR $range');
  }
  return GraphHeadline(
    value: number(latest),
    change: displayWeightOf(context, change),
    note: range,
  );
}

/// How big a headline is drawn.
enum GraphHeadlineSize { tile, inline, page }

/// A headline: the value with its unit (and a PR tag), then the change or
/// the note. Its height never depends on what it says.
class GraphHeadlineView extends StatelessWidget {
  const GraphHeadlineView({
    super.key,
    required this.headline,
    this.size = GraphHeadlineSize.page,
  });

  final GraphHeadline headline;
  final GraphHeadlineSize size;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final muted = theme.colors.mutedForeground;
    final (valueSize, unitSize, noteStyle) = switch (size) {
      GraphHeadlineSize.tile => (20.0, 12.0, theme.typography.body.xs),
      GraphHeadlineSize.inline => (24.0, 14.0, theme.typography.body.sm),
      GraphHeadlineSize.page => (34.0, 17.0, theme.typography.body.sm),
    };
    final valueStyle = theme.typography.body.md.copyWith(
      fontSize: valueSize,
      height: 1.15,
      fontWeight: FontWeight.w600,
      letterSpacing: -valueSize * 0.02,
      color: theme.colors.foreground,
    );
    final value = headline.value;
    final change = headline.change;
    final unit = weightUnitOf(context).symbol;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Flexible(
              child: Text.rich(
                value == null
                    ? TextSpan(
                        text: 'No sessions',
                        style: valueStyle.copyWith(
                          fontSize: unitSize + 2,
                          fontWeight: FontWeight.w500,
                          color: muted,
                          letterSpacing: 0,
                        ),
                      )
                    : TextSpan(
                        text: value,
                        children: <InlineSpan>[
                          TextSpan(
                            text: ' $unit',
                            style: TextStyle(
                              fontSize: unitSize,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                style: valueStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // The line keeps the value's height even when it says
                // "No sessions" in smaller type.
                strutStyle: StrutStyle(
                  fontSize: valueSize,
                  height: 1.15,
                  forceStrutHeight: true,
                ),
              ),
            ),
            if (headline.isRecord) ...[
              const SizedBox(width: 6),
              const RecordTag(),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: <Widget>[
            if (change != null) ...[
              Icon(
                change > 0
                    ? FLucideIcons.trendingUp
                    : change < 0
                    ? FLucideIcons.trendingDown
                    : FLucideIcons.moveRight,
                size: size == GraphHeadlineSize.tile ? 13 : 15,
                color: theme.colors.foreground,
              ),
              const SizedBox(width: 4),
              Text(
                '${formatDecimal((change.abs() * 10).round() / 10)} $unit ',
                style: noteStyle.copyWith(color: theme.colors.foreground),
              ),
            ],
            Expanded(
              child: Text(
                headline.note,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: noteStyle.copyWith(color: muted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "PR", outlined in ink: the value read is the best ever at the time.
class RecordTag extends StatelessWidget {
  const RecordTag({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: theme.colors.foreground),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        'PR',
        style: theme.typography.body.xs.copyWith(
          fontSize: 10.5,
          height: 1,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: theme.colors.foreground,
        ),
      ),
    );
  }
}
