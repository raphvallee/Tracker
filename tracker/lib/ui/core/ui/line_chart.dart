import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/services/analytics.dart';

/// Minimal dependency-free line chart for [ProgressionPoint] series
/// (Milestone 6 analytics). A plain [CustomPainter] - no charting package -
/// plotting a polyline + point dots over a light grid with y-axis tick
/// labels and x-axis date labels.
class LineChart extends StatelessWidget {
  const LineChart({
    super.key,
    required this.points,
    this.height = 160,
    this.unit = '',
  });

  /// Sorted ascending by date.
  final List<ProgressionPoint> points;
  final double height;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No data yet',
            style: theme.typography.body.xs.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _LineChartPainter(
          points: points,
          unit: unit,
          lineColor: theme.colors.primary,
          dotColor: theme.colors.primary,
          // Full theme style (family included) so labels don't fall back to
          // the blocky test/default font.
          labelStyle: theme.typography.body.xs.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.points,
    required this.unit,
    required this.lineColor,
    required this.dotColor,
    required this.labelStyle,
  });

  static const double _minGutter = 32;
  static const double _topPad = 8;
  static const double _rightPad = 12;
  static const double _bottomPad = 18;
  static const int _tickCount = 4;
  static const int _maxXLabels = 5;

  static const List<String> _monthAbbrev = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
  ];

  final List<ProgressionPoint> points;
  final String unit;
  final Color lineColor;
  final Color dotColor;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    // Labels are painted through a clip so an over-long value can never
    // bleed past the chart bounds.
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    var minY = points.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    var maxY = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    if (maxY - minY < 1e-9) {
      // Flat series: give the line vertical room.
      minY -= 1;
      maxY += 1;
    }

    // Y-axis ticks: lay out the labels first so the left gutter always fits
    // the widest one.
    final ticks = <(double, TextPainter)>[
      for (var i = 0; i < _tickCount; i++)
        _tickLabel(
          minY + (maxY - minY) * i / (_tickCount - 1),
          withUnit: i == _tickCount - 1,
        ),
    ];
    // Floor at _minGutter (never throws on degenerate widths, unlike a
    // clamp whose bounds can cross) so the early-out below stays safe.
    final gutter = math.max(
      _minGutter,
      math.min(
        ticks.map((t) => t.$2.width).reduce((a, b) => a > b ? a : b) + 8,
        size.width / 3,
      ),
    );

    final chartWidth = size.width - gutter - _rightPad;
    final chartHeight = size.height - _topPad - _bottomPad;
    if (chartWidth <= 0 || chartHeight <= 0) {
      _dispose(ticks);
      canvas.restore();
      return;
    }

    double yFor(double value) =>
        _topPad + chartHeight * (1 - (value - minY) / (maxY - minY));

    // X positions: proportional to the point dates, spanning the full chart
    // width (min date at the left edge, max date at the right edge).
    final minDate = points
        .map((p) => p.date)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final maxDate = points
        .map((p) => p.date)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final dateRangeMs =
        maxDate.millisecondsSinceEpoch - minDate.millisecondsSinceEpoch;
    // Single point, or all points sharing one date: center it and skip the
    // labels rather than dividing by zero.
    final centered = points.length == 1 || dateRangeMs <= 0;
    double xFor(int i) {
      if (chartWidth <= 1) return gutter;
      if (centered) return gutter + chartWidth / 2;
      return gutter +
          chartWidth *
              (points[i].date.millisecondsSinceEpoch -
                  minDate.millisecondsSinceEpoch) /
              dateRangeMs;
    }

    // Gridlines + tick labels.
    final gridPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (final (value, label) in ticks) {
      final y = yFor(value);
      canvas.drawLine(
        Offset(gutter, y),
        Offset(size.width - _rightPad, y),
        gridPaint,
      );
      label.paint(
        canvas,
        Offset(gutter - 8 - label.width, y - label.height / 2),
      );
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..color = dotColor;

    // Polyline.
    final path = Path()..moveTo(xFor(0), yFor(points[0].value));
    for (var i = 1; i < points.length; i++) {
      path.lineTo(xFor(i), yFor(points[i].value));
    }
    canvas.drawPath(path, linePaint);

    // Point dots.
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(Offset(xFor(i), yFor(points[i].value)), 3, dotPaint);
    }

    // X-axis date labels in the reserved bottom gutter. Same clip as the y
    // labels keeps an over-long label from bleeding past the chart bounds.
    final xLabels = <(double, TextPainter)>[
      if (!centered)
        for (final (date, text) in _xLabels(minDate, maxDate))
          (
            gutter +
                chartWidth *
                    (date.millisecondsSinceEpoch -
                        minDate.millisecondsSinceEpoch) /
                    dateRangeMs,
            TextPainter(
              text: TextSpan(text: text, style: labelStyle),
              textDirection: TextDirection.ltr,
            )..layout(),
          ),
    ];
    for (final (x, label) in xLabels) {
      label.paint(
        canvas,
        Offset(
          x - label.width / 2,
          _topPad +
              chartHeight +
              math.max(0.0, (_bottomPad - label.height) / 2),
        ),
      );
    }

    _dispose(ticks);
    _dispose(xLabels);
    canvas.restore();
  }

  /// ~3-5 label dates on nice calendar boundaries (start of day/week/month/
  /// year depending on the span), clamped to [minDate, maxDate], each with
  /// its formatted label. May come back short or empty for degenerate spans.
  List<(DateTime, String)> _xLabels(DateTime minDate, DateTime maxDate) {
    final span = maxDate.difference(minDate);
    String dayMonth(DateTime d) => '${d.day} ${_monthAbbrev[d.month - 1]}';
    // Under ~2 days: daily boundaries.
    if (span <= const Duration(days: 2)) {
      return _cap([
        for (final d in _dayBoundaries(minDate, maxDate, 1)) (d, dayMonth(d)),
      ]);
    }
    // Under ~1 month: weekly (start of week) boundaries.
    if (span <= const Duration(days: 31)) {
      return _cap([
        for (final d in _dayBoundaries(minDate, maxDate, 7, weekStart: true))
          (d, dayMonth(d)),
      ]);
    }
    // Under ~2 years: start-of-month boundaries, stepping whole months so
    // the labels stay evenly spaced.
    if (span < const Duration(days: 730)) {
      final step = math.max(1, (span.inDays / 30.44 / 4).ceil());
      return _cap([
        for (final d in _monthBoundaries(minDate, maxDate, step))
          (d, '${_monthAbbrev[d.month - 1]} ${d.year % 100}'),
      ]);
    }
    // Longer: year boundaries.
    return _cap([
      for (final d in _yearBoundaries(minDate, maxDate)) (d, '${d.year}'),
    ]);
  }

  /// Evenly downsamples [labels] to at most [_maxXLabels] entries so a dense
  /// boundary list can never crowd the gutter.
  List<(DateTime, String)> _cap(List<(DateTime, String)> labels) {
    if (labels.length <= _maxXLabels) return labels;
    final stride = labels.length / _maxXLabels;
    return [for (var i = 0; i < _maxXLabels; i++) labels[(i * stride).floor()]];
  }

  /// Midnights every [stepDays] days from [minDate]'s day, aligned to Monday
  /// when [weekStart] is set.
  List<DateTime> _dayBoundaries(
    DateTime minDate,
    DateTime maxDate,
    int stepDays, {
    bool weekStart = false,
  }) {
    var d = DateTime(minDate.year, minDate.month, minDate.day);
    if (weekStart) {
      // Align to Monday (DateTime.monday == 1).
      d = d.subtract(Duration(days: (d.weekday + 6) % 7));
    }
    final out = <DateTime>[];
    while (!d.isAfter(maxDate)) {
      if (!d.isBefore(minDate)) out.add(d);
      d = d.add(Duration(days: stepDays));
    }
    return out;
  }

  /// Starts of every [stepMonths]-th month from [minDate] to [maxDate],
  /// anchored so boundaries stay on stable calendar multiples of the step.
  List<DateTime> _monthBoundaries(
    DateTime minDate,
    DateTime maxDate,
    int stepMonths,
  ) {
    // Month count from a fixed epoch so the step alignment is stable.
    final firstMonth = minDate.year * 12 + minDate.month - 1;
    final out = <DateTime>[];
    for (var m = (firstMonth ~/ stepMonths) * stepMonths; ; m += stepMonths) {
      final d = DateTime(m ~/ 12, m % 12 + 1);
      if (d.isAfter(maxDate)) break;
      if (!d.isBefore(minDate)) out.add(d);
    }
    return out;
  }

  /// Starts of each year from [minDate] to [maxDate].
  List<DateTime> _yearBoundaries(DateTime minDate, DateTime maxDate) {
    final out = <DateTime>[];
    for (var y = minDate.year; y <= maxDate.year; y++) {
      final d = DateTime(y);
      if (!d.isBefore(minDate) && !d.isAfter(maxDate)) out.add(d);
    }
    return out;
  }

  void _dispose(List<(double, TextPainter)> labels) {
    for (final (_, label) in labels) {
      label.dispose();
    }
  }

  (double, TextPainter) _tickLabel(double value, {required bool withUnit}) {
    final text = withUnit && unit.isNotEmpty
        ? '${_fmt(value)} $unit'
        : _fmt(value);
    final painter = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    return (value, painter);
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  bool shouldRepaint(_LineChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.dotColor != dotColor ||
      oldDelegate.labelStyle != labelStyle;
}
