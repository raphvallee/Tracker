import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/graph_config.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/domain/services/graph_series.dart';
import 'package:tracker/ui/core/ui/relative_dates.dart';

/// How a chart answers the pointer.
enum GraphInput {
  /// Hover only: a tile, whose tap opens the graph.
  hover,

  /// A tap, a drag or a hold reads a point; it stays read until the same
  /// point is tapped again. Hover reads too.
  full,
}

/// A graph's points over time, in the form its metric calls for: a line of
/// each session (estimated 1RM, heaviest weight), a staircase of bests over
/// faint sessions (1RM PR), or columns per week or month (volume). Drawn in
/// ink; [compact] drops the axes for a tile.
class GraphChart extends StatefulWidget {
  const GraphChart({
    super.key,
    required this.series,
    required this.unit,
    required this.height,
    this.compact = false,
    this.input = GraphInput.full,
    this.surface,
    this.onSelect,
  });

  final GraphSeries series;
  final WeightUnit unit;
  final double height;
  final bool compact;
  final GraphInput input;

  /// What the chart sits on: the rings around its dots take this color.
  final Color? surface;

  /// The point read: an index into the series' sessions, or into its
  /// buckets for volume; null when none is.
  final ValueChanged<int?>? onSelect;

  @override
  State<GraphChart> createState() => _GraphChartState();
}

class _GraphChartState extends State<GraphChart> {
  /// Read by touch or click; stays until tapped again.
  int? _pinned;

  /// Under the mouse; shown over [_pinned] while it hovers.
  int? _hover;

  int? _pinnedAtTapDown;
  int? _tapped;

  int? get _selected => _hover ?? _pinned;

  @override
  void didUpdateWidget(GraphChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.series, widget.series)) return;
    final had = _selected != null;
    _pinned = _hover = null;
    // A new range or new data: the old point means nothing on it.
    if (had) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onSelect?.call(null);
      });
    }
  }

  void _update({required int? pinned, required int? hover}) {
    // The mouse reports every pixel it moves; most stay on the same point.
    if (pinned == _pinned && hover == _hover) return;
    final before = _selected;
    setState(() {
      _pinned = pinned;
      _hover = hover;
    });
    if (_selected != before) widget.onSelect?.call(_selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tickStyle = theme.typography.body.xs.copyWith(
      fontSize: 10.5,
      height: 1,
      color: theme.colors.mutedForeground,
      fontFeatures: const [ui.FontFeature.tabularFigures()],
    );
    final textScaler = MediaQuery.textScalerOf(context);
    // Laid out from the box's size where it is needed (painting, the
    // pointer), never in build: the chart keeps its intrinsic height, so a
    // row of tiles can match heights.
    _Layout layoutFor(Size size) => _Layout(
      series: widget.series,
      size: size,
      unit: widget.unit,
      compact: widget.compact,
      tickStyle: tickStyle,
      textScaler: textScaler,
    );
    int? at(Offset position) {
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return null;
      return layoutFor(box.size).nearest(position.dx);
    }

    Widget chart = SizedBox(
      height: widget.height,
      width: double.infinity,
      child: CustomPaint(
        painter: _GraphPainter(
          layoutFor: layoutFor,
          series: widget.series,
          unit: widget.unit,
          compact: widget.compact,
          tickStyle: tickStyle,
          selected: _selected,
          ink: theme.colors.foreground,
          surface: widget.surface ?? theme.colors.background,
          grid: theme.colors.border,
          muted: theme.colors.mutedForeground,
        ),
      ),
    );
    chart = MouseRegion(
      onHover: (event) =>
          _update(pinned: _pinned, hover: at(event.localPosition)),
      onExit: (_) => _update(pinned: _pinned, hover: null),
      child: chart,
    );
    if (widget.input == GraphInput.hover) return chart;
    void pin(Offset position) => _update(pinned: at(position), hover: null);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) {
        _pinnedAtTapDown = _pinned;
        _tapped = at(details.localPosition);
        _update(pinned: _tapped, hover: null);
      },
      // Tapping the point that is read puts it away.
      onTapUp: (_) {
        if (_tapped != null && _tapped == _pinnedAtTapDown) {
          _update(pinned: null, hover: null);
        }
      },
      onHorizontalDragStart: (details) => pin(details.localPosition),
      onHorizontalDragUpdate: (details) => pin(details.localPosition),
      onLongPressStart: (details) => pin(details.localPosition),
      onLongPressMoveUpdate: (details) => pin(details.localPosition),
      child: chart,
    );
  }
}

/// Where everything goes, in the units shown: shared by the painter and
/// the pointer, which reads the point nearest it.
class _Layout {
  factory _Layout({
    required GraphSeries series,
    required Size size,
    required WeightUnit unit,
    required bool compact,
    required TextStyle tickStyle,
    required TextScaler textScaler,
  }) {
    double show(double kilograms) => unit.fromKilograms(kilograms);
    final bars = series.metric == GraphMetric.volume;
    final values = <double>[
      if (bars)
        for (final bucket in series.buckets) show(bucket.value)
      else
        for (final session in series.sessions) ...[
          show(session.value),
          if (series.metric == GraphMetric.record1rm) show(session.best),
        ],
      if (series.metric == GraphMetric.record1rm && series.bestBefore != null)
        show(series.bestBefore!),
    ];
    var (lo, hi) = (0.0, 1.0);
    if (values.isNotEmpty) {
      lo = bars ? 0 : values.reduce(math.min);
      hi = values.reduce(math.max);
      if (hi - lo < 1e-9) {
        final pad = math.max(1.0, hi.abs() * 0.02);
        if (!bars) lo -= pad;
        hi += pad;
      } else {
        final pad = (hi - lo) * (compact ? 0.1 : 0.14);
        if (!bars) lo -= pad;
        hi += pad;
      }
    }
    final step = _niceStep(hi - lo, 3);
    final ticks = <double>[
      if (!compact)
        for (
          var t = (lo / step).ceil() * step;
          t <= hi + step * 1e-6;
          t += step
        )
          t,
    ];
    var gutter = 0.0;
    if (!compact) {
      for (final tick in ticks) {
        final painter = TextPainter(
          text: TextSpan(text: _tickText(tick, step), style: tickStyle),
          textDirection: TextDirection.ltr,
          textScaler: textScaler,
        )..layout();
        gutter = math.max(gutter, painter.width);
        painter.dispose();
      }
      gutter = math.max(24, gutter + 8);
    }
    final top = compact ? 4.0 : 6.0;
    final bottom = compact ? 4.0 : 22.0;
    final plot = Rect.fromLTRB(
      0,
      top,
      math.max(1, size.width - gutter),
      math.max(top + 1, size.height - bottom),
    );
    return _Layout._(
      series: series,
      size: size,
      unit: unit,
      compact: compact,
      tickStyle: tickStyle,
      textScaler: textScaler,
      plot: plot,
      lo: lo,
      hi: hi,
      step: step,
      ticks: ticks,
    );
  }

  _Layout._({
    required this.series,
    required this.size,
    required this.unit,
    required this.compact,
    required this.tickStyle,
    required this.textScaler,
    required this.plot,
    required this.lo,
    required this.hi,
    required this.step,
    required this.ticks,
  }) {
    final bars = series.metric == GraphMetric.volume;
    if (bars) {
      final slot = plot.width / math.max(1, series.buckets.length);
      xs = [
        for (var i = 0; i < series.buckets.length; i++)
          plot.left + slot * (i + 0.5),
      ];
    } else {
      xs = [for (final session in series.sessions) xOf(session.date)];
    }
  }

  final GraphSeries series;
  final Size size;
  final WeightUnit unit;
  final bool compact;
  final TextStyle tickStyle;
  final TextScaler textScaler;
  final Rect plot;
  final double lo;
  final double hi;
  final double step;
  final List<double> ticks;

  /// Where each point sits across: a session, or a column's middle.
  late final List<double> xs;

  /// The first and last x a line may reach: room for the end dot.
  double get xStart => plot.left + 4;
  double get xEnd => plot.right - (compact ? 4 : 6);

  double show(double kilograms) => unit.fromKilograms(kilograms);

  double yOf(double shown) =>
      plot.top + plot.height * (1 - (shown - lo) / (hi - lo));

  double xOf(DateTime date) {
    final span = series.to.difference(series.from).inMilliseconds;
    if (span <= 0) return (xStart + xEnd) / 2;
    final t = date.difference(series.from).inMilliseconds / span;
    return xStart + (xEnd - xStart) * t.clamp(0.0, 1.0);
  }

  int? nearest(double dx) {
    if (xs.isEmpty) return null;
    var best = 0;
    for (var i = 1; i < xs.length; i++) {
      if ((xs[i] - dx).abs() < (xs[best] - dx).abs()) best = i;
    }
    return best;
  }

  /// The time axis' labels: Mondays over a month, month starts beyond
  /// (January shown as its year); columns label every few from the newest.
  List<(double, String)> xLabels() {
    if (compact) return const [];
    if (series.metric == GraphMetric.volume) {
      final buckets = series.buckets;
      final every = math.max(1, (buckets.length / 5).ceil());
      return [
        for (var i = 0; i < buckets.length; i++)
          if ((buckets.length - 1 - i) % every == 0)
            (
              xs[i],
              series.period == GraphPeriod.week
                  ? dayMonthLabel(buckets[i].start)
                  : _monthText(buckets[i].start),
            ),
      ];
    }
    final from = series.from, to = series.to;
    final days = to.difference(from).inDays;
    if (days <= 0) return const [];
    if (days <= 40) {
      return [
        for (
          var d = DateTime(from.year, from.month, from.day + 1);
          !d.isAfter(to);
          d = DateTime(d.year, d.month, d.day + 1)
        )
          if (d.weekday == DateTime.monday) (xOf(d), dayMonthLabel(d)),
      ];
    }
    final months = days <= 120
        ? 1
        : days <= 240
        ? 2
        : days <= 400
        ? 3
        : days <= 800
        ? 6
        : 12;
    final labels = <(double, String)>[];
    var d = DateTime(from.year, from.month + 1);
    while ((d.month - 1) % months != 0) {
      d = DateTime(d.year, d.month + 1);
    }
    for (; !d.isAfter(to); d = DateTime(d.year, d.month + months)) {
      labels.add((xOf(d), _monthText(d)));
    }
    return labels;
  }

  static String _monthText(DateTime d) =>
      d.month == 1 ? '${d.year}' : shortMonthName(d.month);
}

double _niceStep(double span, int count) {
  if (span <= 0) return 1;
  final raw = span / count;
  final magnitude = math
      .pow(10, (math.log(raw) / math.ln10).floor())
      .toDouble();
  final f = raw / magnitude;
  return (f <= 1
          ? 1
          : f <= 2
          ? 2
          : f <= 5
          ? 5
          : 10) *
      magnitude;
}

String _tickText(double value, double step) {
  if (value.abs() >= 1000) {
    final k = value / 1000;
    final text = k == k.roundToDouble()
        ? k.toStringAsFixed(0)
        : k.toStringAsFixed(1);
    return '${text}K';
  }
  return step < 1 ? value.toStringAsFixed(1) : value.toStringAsFixed(0);
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({
    required this.layoutFor,
    required this.series,
    required this.unit,
    required this.compact,
    required this.tickStyle,
    required this.selected,
    required this.ink,
    required this.surface,
    required this.grid,
    required this.muted,
  });

  final _Layout Function(Size size) layoutFor;
  final GraphSeries series;
  final WeightUnit unit;
  final bool compact;
  final TextStyle tickStyle;
  final int? selected;
  final Color ink;
  final Color surface;
  final Color grid;
  final Color muted;

  late _Layout layout;

  @override
  void paint(Canvas canvas, Size size) {
    layout = layoutFor(size);
    if (!layout.compact) _axes(canvas, size);
    switch (layout.series.metric) {
      case GraphMetric.volume:
        _columns(canvas);
      case GraphMetric.record1rm:
        _staircase(canvas);
      case GraphMetric.best1rm:
      case GraphMetric.peakWeight:
        _line(canvas, size);
    }
  }

  TextPainter _text(String text) => TextPainter(
    text: TextSpan(text: text, style: layout.tickStyle),
    textDirection: TextDirection.ltr,
    textScaler: layout.textScaler,
  )..layout();

  void _axes(Canvas canvas, Size size) {
    final l = layout;
    final rule = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final tick in l.ticks) {
      final y = l.yOf(tick).roundToDouble() + 0.5;
      canvas.drawLine(Offset(l.plot.left, y), Offset(l.plot.right, y), rule);
      final label = _text(_tickText(tick, l.step));
      label.paint(
        canvas,
        Offset(size.width - label.width, y - label.height / 2),
      );
      label.dispose();
    }
    var lastRight = double.negativeInfinity;
    for (final (x, text) in l.xLabels()) {
      final label = _text(text);
      final left = x - label.width / 2;
      final fits =
          left >= l.plot.left - 2 &&
          left + label.width <= l.plot.right + 4 &&
          left >= lastRight + 8;
      if (fits) {
        label.paint(canvas, Offset(left, l.plot.bottom + 7));
        lastRight = left + label.width;
      }
      label.dispose();
    }
  }

  Paint _stroke(double alpha) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = layout.compact ? 1.75 : 2
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = ink.withValues(alpha: alpha);

  /// A dot in ink on a ring of the surface, so it reads over a line.
  void _dot(Canvas canvas, Offset center, double radius, [double alpha = 1]) {
    canvas.drawCircle(
      center,
      radius + (layout.compact ? 1.5 : 2),
      Paint()..color = surface,
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = ink.withValues(alpha: alpha),
    );
  }

  void _readLine(Canvas canvas, double x) {
    final at = x.roundToDouble() + 0.5;
    canvas.drawLine(
      Offset(at, layout.plot.top - 2),
      Offset(at, layout.plot.bottom),
      Paint()
        ..color = ink
        ..strokeWidth = 1,
    );
  }

  void _line(Canvas canvas, Size size) {
    final l = layout;
    final sessions = l.series.sessions;
    if (sessions.isEmpty) return;
    final xs = l.xs;
    final ys = [for (final s in sessions) l.yOf(l.show(s.value))];
    final line = Path()..moveTo(xs.first, ys.first);
    for (var i = 1; i < xs.length; i++) {
      line.lineTo(xs[i], ys[i]);
    }
    final wash = Path.from(line)
      ..lineTo(xs.last, l.plot.bottom)
      ..lineTo(xs.first, l.plot.bottom)
      ..close();
    final washPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, l.plot.top),
        Offset(0, l.plot.bottom),
        [ink.withValues(alpha: 0.09), ink.withValues(alpha: 0)],
      );
    final read = selected;
    if (read == null) {
      if (xs.length > 1) {
        canvas.drawPath(wash, washPaint);
        canvas.drawPath(line, _stroke(1));
      }
      _dot(canvas, Offset(xs.last, ys.last), l.compact ? 3.2 : 4.5);
      return;
    }
    // The line up to the point read stays; the rest steps back.
    canvas.drawPath(line, _stroke(0.2));
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, xs[read] + 0.5, size.height));
    canvas.drawPath(wash, washPaint);
    canvas.drawPath(line, _stroke(1));
    canvas.restore();
    _readLine(canvas, xs[read]);
    _dot(canvas, Offset(xs[read], ys[read]), 4.5);
  }

  void _staircase(Canvas canvas) {
    final l = layout;
    final sessions = l.series.sessions;
    final before = l.series.bestBefore;
    if (sessions.isEmpty && before == null) return;
    final read = selected;
    final dim = read != null;
    final xs = l.xs;
    final path = Path();
    var best = l.show(before ?? sessions.first.best);
    path.moveTo(before == null ? xs.first : l.xStart, l.yOf(best));
    for (var i = 0; i < sessions.length; i++) {
      final next = l.show(sessions[i].best);
      path.lineTo(xs[i], l.yOf(best));
      if (next != best) path.lineTo(xs[i], l.yOf(next));
      best = next;
    }
    path.lineTo(l.xEnd, l.yOf(best));

    final faint = Paint()
      ..color = ink.withValues(alpha: dim ? 0.14 : (l.compact ? 0.25 : 0.22));
    for (var i = 0; i < sessions.length; i++) {
      if (sessions[i].isRecord) continue;
      canvas.drawCircle(
        Offset(xs[i], l.yOf(l.show(sessions[i].value))),
        l.compact ? 1.6 : 2.4,
        faint,
      );
    }
    canvas.drawPath(path, _stroke(dim ? 0.35 : 1));
    for (var i = 0; i < sessions.length; i++) {
      if (!sessions[i].isRecord) continue;
      _dot(
        canvas,
        Offset(xs[i], l.yOf(l.show(sessions[i].value))),
        l.compact ? 2.4 : 3.2,
        dim ? 0.35 : 1,
      );
    }
    if (read != null) {
      _readLine(canvas, xs[read]);
      _dot(canvas, Offset(xs[read], l.yOf(l.show(sessions[read].value))), 4.5);
    }
  }

  void _columns(Canvas canvas) {
    final l = layout;
    final buckets = l.series.buckets;
    if (buckets.isEmpty) return;
    final slot = l.plot.width / buckets.length;
    final width = math.min(l.compact ? 8.0 : 12.0, slot * 0.6);
    final radius = Radius.circular(math.min(4, width / 2));
    final read = selected;
    for (var i = 0; i < buckets.length; i++) {
      final bucket = buckets[i];
      if (bucket.value <= 0) continue;
      final top = math.min(l.yOf(l.show(bucket.value)), l.plot.bottom - 2);
      var alpha = bucket.isCurrent ? 0.25 : 1.0;
      if (read != null && read != i) alpha *= 0.3;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(
            l.xs[i] - width / 2,
            top,
            l.xs[i] + width / 2,
            l.plot.bottom,
          ),
          topLeft: radius,
          topRight: radius,
        ),
        Paint()..color = ink.withValues(alpha: alpha),
      );
    }
    final average = l.series.average;
    if (!l.compact && average != null && average > 0) {
      final y = l.yOf(l.show(average)).roundToDouble() + 0.5;
      canvas.drawLine(
        Offset(l.plot.left, y),
        Offset(l.plot.right, y),
        Paint()
          ..color = muted
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_GraphPainter old) =>
      !identical(old.series, series) ||
      old.unit != unit ||
      old.compact != compact ||
      old.tickStyle != tickStyle ||
      old.selected != selected ||
      old.ink != ink ||
      old.surface != surface ||
      old.grid != grid ||
      old.muted != muted;
}
