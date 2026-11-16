import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/graph_config.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/domain/services/graph_series.dart';
import 'package:tracker/ui/core/ui/motion.dart';
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
///
/// A new range moves the chart there on one clock (`docs/MOTION.md`): the
/// time window and the value scale travel together, what both ranges show
/// slides to its new place, what only the new one shows comes in with the
/// room it fills, and labels fade out early and in late.
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

class _GraphChartState extends State<GraphChart>
    with SingleTickerProviderStateMixin {
  /// Read by touch or click; stays until tapped again.
  int? _pinned;

  /// Under the mouse; shown over [_pinned] while it hovers.
  int? _hover;

  int? _pinnedAtTapDown;
  int? _tapped;

  late final AnimationController _motion = AnimationController(vsync: this)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed && _plan is _Move) {
        setState(() => _plan = _Rest(_plan.series));
      }
    });

  late _Plan _plan = _Rest(widget.series);

  int? get _selected => _hover ?? _pinned;

  @override
  void didUpdateWidget(GraphChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.series, widget.series)) return;
    _plan = _planFor(oldWidget);
    final had = _selected != null;
    _pinned = _hover = null;
    // A new range or new data: the old point means nothing on it.
    if (had) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onSelect?.call(null);
      });
    }
  }

  /// What the chart shows next: a move to the new range, or the new series
  /// at once when there is nothing to move between.
  _Plan _planFor(GraphChart oldWidget) {
    final next = widget.series;
    final shown = _plan.series;
    final same =
        shown.metric == next.metric &&
        oldWidget.unit == widget.unit &&
        oldWidget.compact == widget.compact &&
        _drawable(shown) &&
        _drawable(next);
    final current = _plan;
    if (!same) {
      _motion.stop();
      return _Rest(next);
    }
    if (shown.range == next.range) {
      // New data in the same range: a running move carries on to it.
      if (current is _Move && _motion.isAnimating) {
        return _Move(current.from, next, _motion);
      }
      return _Rest(next);
    }
    final duration = Motion.of(
      context,
      next.from.isBefore(shown.from) ? Motion.roomIn : Motion.roomOut,
    );
    if (duration == Duration.zero) {
      _motion.stop();
      return _Rest(next);
    }
    // Picked again mid-move: the new move starts from where the chart is.
    _Plan from = current;
    if (current is _Move) {
      from = _Move(
        // Three ranges picked in a row: the oldest is dropped.
        current.from is _Move ? _Rest(current.from.series) : current.from,
        current.series,
        AlwaysStoppedAnimation(_motion.value),
      );
    }
    _motion
      ..duration = duration
      ..forward(from: 0);
    return _Move(from, next, _motion);
  }

  static bool _drawable(GraphSeries series) => switch (series.metric) {
    GraphMetric.volume => series.buckets.isNotEmpty,
    GraphMetric.record1rm =>
      series.sessions.isNotEmpty || series.bestBefore != null,
    GraphMetric.best1rm || GraphMetric.peakWeight => series.sessions.isNotEmpty,
  };

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
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
    _Layout layoutFor(GraphSeries series, Size size) => _Layout(
      series: series,
      size: size,
      unit: widget.unit,
      compact: widget.compact,
      tickStyle: tickStyle,
      textScaler: textScaler,
    );
    int? at(Offset position) {
      // Nothing is read while the chart moves to a new range.
      if (_plan is _Move) return null;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return null;
      return layoutFor(_plan.series, box.size).nearest(position.dx);
    }

    Widget chart = SizedBox(
      height: widget.height,
      width: double.infinity,
      child: CustomPaint(
        painter: _GraphPainter(
          plan: _plan,
          motion: _motion,
          layoutFor: layoutFor,
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

/// What the chart shows: one series at rest, or a move from what it showed
/// to a new series.
sealed class _Plan {
  const _Plan(this.series);

  /// The series shown at rest, or the one a move ends on.
  final GraphSeries series;

  /// Every series the chart is drawn from, oldest first.
  List<GraphSeries> get chain;
}

class _Rest extends _Plan {
  const _Rest(super.series);

  @override
  List<GraphSeries> get chain => [series];
}

/// On its way from [from] to [series]; [progress] runs from 0 to 1.
class _Move extends _Plan {
  const _Move(this.from, super.series, this.progress);

  final _Plan from;
  final Animation<double> progress;

  @override
  List<GraphSeries> get chain => [...from.chain, series];
}

/// Where things go and how much of each is shown, at rest (a [_Layout]) or
/// partway through a move (a [_Blend]). A view is a window on the data: a
/// span of time laid over a span across, and a span of values over the
/// plot's height. A move slides the window, so everything in it moves as
/// one camera would show it. Presence runs from 0 (gone) to 1.
abstract class _View {
  const _View();

  Rect get plot;

  /// The first and last x a line may reach: room for the end dot.
  double get xStart;
  double get xEnd;

  /// The time window, in milliseconds since the epoch, and where across
  /// its two ends sit.
  double get t0;
  double get t1;
  double get x0;
  double get x1;

  /// The values at the bottom and the top of the plot, in the units shown.
  double get lo;
  double get hi;

  /// What the columns stand for; null for a line.
  GraphPeriod? get period;

  /// The middle of a column, for a week or a month of either period.
  double column(GraphPeriod period, DateTime start);
  double get columnWidth;

  /// The volume average, in the units shown; null when there is none.
  double? get average;

  double get averageShown;
  double sessionShown(int sessionId);
  double bucketShown(_BucketKey key);
  double tickShown(int key);
  double labelShown(Object key);

  /// Across, for a time; not clamped, so a date outside the window lands
  /// beyond the plot.
  double x(DateTime date) {
    final span = t1 - t0;
    if (span <= 0) return (x0 + x1) / 2;
    return x0 + (x1 - x0) * (date.millisecondsSinceEpoch - t0) / span;
  }

  /// Down, for a value in the units shown.
  double y(double shown) =>
      plot.top + plot.height * (1 - (shown - lo) / (hi - lo));
}

typedef _BucketKey = (GraphPeriod, DateTime);

int _tickKey(double value) => (value * 1e6).round();

/// A label on the time axis: where it goes on any view, and what it says.
class _AxisLabel {
  const _AxisLabel(this.key, this.at, this.text);

  final Object key;
  final double Function(_View view) at;
  final String text;
}

/// Where everything goes, in the units shown: shared by the painter and
/// the pointer, which reads the point nearest it.
class _Layout extends _View {
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
      xs = [
        for (var i = 0; i < series.buckets.length; i++)
          plot.left + _slot * (i + 0.5),
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
  @override
  final Rect plot;
  @override
  final double lo;
  @override
  final double hi;
  final double step;
  final List<double> ticks;

  /// Where each point sits across: a session, or a column's middle.
  late final List<double> xs;

  double get _slot => plot.width / math.max(1, series.buckets.length);

  /// The first and last x a line may reach: room for the end dot.
  @override
  double get xStart => plot.left + 4;
  @override
  double get xEnd => plot.right - (compact ? 4 : 6);

  double show(double kilograms) => unit.fromKilograms(kilograms);

  double yOf(double shown) => y(shown);

  /// Across for [date], held inside the range.
  double xOf(DateTime date) => x(date).clamp(xStart, xEnd);

  bool get _bars =>
      series.metric == GraphMetric.volume &&
      period != null &&
      series.buckets.isNotEmpty;

  @override
  GraphPeriod? get period => series.period;

  // A line spreads its range over its reach; columns spread their weeks or
  // months, the running one whole, over the plot.
  @override
  late final double t0 = (_bars ? series.buckets.first.start : series.from)
      .millisecondsSinceEpoch
      .toDouble();

  @override
  late final double t1 =
      (_bars ? _end(series.buckets.last.start, period!) : series.to)
          .millisecondsSinceEpoch
          .toDouble();

  @override
  double get x0 => _bars ? plot.left : xStart;

  @override
  double get x1 => _bars ? plot.right : xEnd;

  @override
  double column(GraphPeriod period, DateTime start) {
    final buckets = series.buckets;
    final own = series.period;
    if (buckets.isEmpty || own == null) return plot.center.dx;
    if (period == own) {
      final index =
          _ordinal(start, period) - _ordinal(buckets.first.start, period);
      return plot.left + _slot * (index + 0.5);
    }
    // A week on a chart of months, or the other way: placed by time.
    return x(_middle(start, period));
  }

  @override
  double get columnWidth => math.min(compact ? 8.0 : 12.0, _slot * 0.6);

  @override
  late final double? average = () {
    final average = series.average;
    if (compact || average == null || average <= 0) return null;
    return show(average);
  }();

  @override
  double get averageShown => average == null ? 0 : 1;

  late final Set<int> _sessionIds = {
    for (final session in series.sessions) session.sessionId,
  };

  late final Set<_BucketKey> _bucketKeys = {
    if (series.period != null)
      for (final bucket in series.buckets) (series.period!, bucket.start),
  };

  late final Set<int> _tickKeys = {for (final tick in ticks) _tickKey(tick)};

  late final Set<Object> _labelKeys = {for (final label in labels) label.key};

  @override
  double sessionShown(int sessionId) => _sessionIds.contains(sessionId) ? 1 : 0;

  @override
  double bucketShown(_BucketKey key) => _bucketKeys.contains(key) ? 1 : 0;

  @override
  double tickShown(int key) => _tickKeys.contains(key) ? 1 : 0;

  @override
  double labelShown(Object key) => _labelKeys.contains(key) ? 1 : 0;

  int? nearest(double dx) {
    if (xs.isEmpty) return null;
    var best = 0;
    for (var i = 1; i < xs.length; i++) {
      if ((xs[i] - dx).abs() < (xs[best] - dx).abs()) best = i;
    }
    return best;
  }

  /// The time axis' labels that fit, left to right, none overlapping.
  late final List<_AxisLabel> labels = () {
    final fitting = <_AxisLabel>[];
    var lastRight = double.negativeInfinity;
    for (final label in _xLabels()) {
      final painter = TextPainter(
        text: TextSpan(text: label.text, style: tickStyle),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();
      final left = label.at(this) - painter.width / 2;
      final fits =
          left >= plot.left - 2 &&
          left + painter.width <= plot.right + 4 &&
          left >= lastRight + 8;
      if (fits) {
        fitting.add(label);
        lastRight = left + painter.width;
      }
      painter.dispose();
    }
    return fitting;
  }();

  /// The time axis' labels: Mondays over a month, month starts beyond
  /// (January shown as its year); columns label every few from the newest.
  List<_AxisLabel> _xLabels() {
    if (compact) return const [];
    final period = series.period;
    if (series.metric == GraphMetric.volume && period != null) {
      final buckets = series.buckets;
      final every = math.max(1, (buckets.length / 5).ceil());
      return [
        for (var i = 0; i < buckets.length; i++)
          if ((buckets.length - 1 - i) % every == 0)
            _columnLabel(
              period,
              buckets[i].start,
              period == GraphPeriod.week
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
          if (d.weekday == DateTime.monday) _dateLabel(d, dayMonthLabel(d)),
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
    final labels = <_AxisLabel>[];
    var d = DateTime(from.year, from.month + 1);
    while ((d.month - 1) % months != 0) {
      d = DateTime(d.year, d.month + 1);
    }
    for (; !d.isAfter(to); d = DateTime(d.year, d.month + months)) {
      labels.add(_dateLabel(d, _monthText(d)));
    }
    return labels;
  }

  static _AxisLabel _dateLabel(DateTime date, String text) =>
      _AxisLabel(('date', date), (view) => view.x(date), text);

  static _AxisLabel _columnLabel(
    GraphPeriod period,
    DateTime start,
    String text,
  ) => _AxisLabel((period, start), (view) => view.column(period, start), text);

  static String _monthText(DateTime d) =>
      d.month == 1 ? '${d.year}' : shortMonthName(d.month);
}

/// Weeks or months since a fixed start: neighbouring columns differ by one.
int _ordinal(DateTime start, GraphPeriod period) => switch (period) {
  GraphPeriod.week =>
    DateTime.utc(
          start.year,
          start.month,
          start.day,
        ).difference(DateTime.utc(1970, 1, 5)).inDays ~/
        7,
  GraphPeriod.month => start.year * 12 + start.month,
};

DateTime _end(DateTime start, GraphPeriod period) => switch (period) {
  GraphPeriod.week => DateTime(start.year, start.month, start.day + 7),
  GraphPeriod.month => DateTime(start.year, start.month + 1),
};

DateTime _middle(DateTime start, GraphPeriod period) =>
    start.add(_end(start, period).difference(start) ~/ 2);

/// [a] on its way to [b], [t] into the move: the window slides from one
/// to the other on one curve, so everything both show moves together (M1,
/// M3) and what only one shows slides in or out past the plot's edge.
class _Blend extends _View {
  _Blend(this.a, this.b, this.t) : e = Motion.enter.transform(t);

  final _View a;
  final _View b;
  final double t;
  final double e;

  double _mix(double from, double to) => from + (to - from) * e;

  @override
  late final Rect plot = Rect.lerp(a.plot, b.plot, e)!;

  @override
  late final double xStart = _mix(a.xStart, b.xStart);

  @override
  late final double xEnd = _mix(a.xEnd, b.xEnd);

  @override
  late final double t0 = _mix(a.t0, b.t0);

  @override
  late final double t1 = _mix(a.t1, b.t1);

  @override
  late final double x0 = _mix(a.x0, b.x0);

  @override
  late final double x1 = _mix(a.x1, b.x1);

  @override
  late final double lo = _mix(a.lo, b.lo);

  @override
  late final double hi = _mix(a.hi, b.hi);

  @override
  GraphPeriod? get period => b.period;

  /// Weeks giving way to months, or back: what only one side shows is
  /// replaced, not slid.
  bool get _swapsPeriod => a.period != b.period;

  @override
  double column(GraphPeriod period, DateTime start) {
    // Placed by time on the moving window, plus how far each end sets it
    // off its time (months are not all as long), so both ends are exact.
    final middle = _middle(start, period);
    return x(middle) +
        _mix(
          a.column(period, start) - a.x(middle),
          b.column(period, start) - b.x(middle),
        );
  }

  @override
  late final double columnWidth = _mix(a.columnWidth, b.columnWidth);

  @override
  late final double? average = () {
    final from = a.average, to = b.average;
    if (from == null || to == null) return from ?? to;
    return _mix(from, to);
  }();

  @override
  double get averageShown =>
      _presence(a.averageShown, b.averageShown, t, _Fade.label);

  @override
  double sessionShown(int sessionId) => _presence(
    a.sessionShown(sessionId),
    b.sessionShown(sessionId),
    t,
    _Fade.data,
  );

  @override
  double bucketShown(_BucketKey key) => _presence(
    a.bucketShown(key),
    b.bucketShown(key),
    t,
    _swapsPeriod ? _Fade.swap : _Fade.data,
  );

  @override
  double tickShown(int key) =>
      _presence(a.tickShown(key), b.tickShown(key), t, _Fade.label);

  @override
  double labelShown(Object key) =>
      _presence(a.labelShown(key), b.labelShown(key), t, _Fade.label);
}

/// How something comes and goes in a move.
enum _Fade {
  /// Data sliding past the plot's edge: it comes in over the first half,
  /// with the room it fills (M4), and goes over the whole move, so the
  /// room it leaves is never empty.
  data,

  /// Columns replaced by columns of another period: the old ones are gone
  /// in the first 30 %, while the new ones rise in with the room, as data
  /// does.
  swap,

  /// Axis labels and the average: out in the first 30 %, in over the last
  /// 60 % (M5).
  label,
}

/// How present something is [t] into a move that takes it from [from] to
/// [to].
double _presence(double from, double to, double t, _Fade fade) {
  if (from == to) return to;
  final leaving = to < from;
  final k = switch (fade) {
    _Fade.data when leaving => Motion.exit.transform(t),
    _Fade.swap || _Fade.label when leaving => (t / 0.3).clamp(0.0, 1.0),
    _Fade.data || _Fade.swap => (t / 0.5).clamp(0.0, 1.0),
    _Fade.label => ((t - 0.4) / 0.6).clamp(0.0, 1.0),
  };
  return from + (to - from) * k;
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
    required this.plan,
    required Animation<double> motion,
    required this.layoutFor,
    required this.unit,
    required this.compact,
    required this.tickStyle,
    required this.selected,
    required this.ink,
    required this.surface,
    required this.grid,
    required this.muted,
  }) : super(repaint: motion);

  final _Plan plan;
  final _Layout Function(GraphSeries series, Size size) layoutFor;
  final WeightUnit unit;
  final bool compact;
  final TextStyle tickStyle;
  final int? selected;
  final Color ink;
  final Color surface;
  final Color grid;
  final Color muted;

  /// Each series laid out once per size, not once per frame of a move.
  final Map<GraphSeries, _Layout> _layouts = {};
  Size? _size;

  /// The series the move ends on (or the one at rest), laid out.
  late _Layout layout;

  _Layout _layoutOf(GraphSeries series, Size size) =>
      _layouts.putIfAbsent(series, () => layoutFor(series, size));

  _View _viewOf(_Plan plan, Size size) => switch (plan) {
    _Rest() => _layoutOf(plan.series, size),
    _Move() => _Blend(
      _viewOf(plan.from, size),
      _layoutOf(plan.series, size),
      plan.progress.value,
    ),
  };

  double show(double kilograms) => unit.fromKilograms(kilograms);

  @override
  void paint(Canvas canvas, Size size) {
    if (size != _size) {
      _layouts.clear();
      _size = size;
    }
    final layouts = [for (final series in plan.chain) _layoutOf(series, size)];
    layout = layouts.last;
    final view = _viewOf(plan, size);
    // A point is read only at rest.
    final read = plan is _Rest ? selected : null;
    if (!compact) _axes(canvas, size, view, layouts);
    canvas.save();
    // What a move brings from beyond the range stays inside the plot.
    canvas.clipRect(
      Rect.fromLTRB(
        view.plot.left - 2,
        0,
        view.plot.right + 2,
        view.plot.bottom + 1,
      ),
    );
    switch (plan.series.metric) {
      case GraphMetric.volume:
        _columns(canvas, view, layouts, read);
      case GraphMetric.record1rm:
        _staircase(canvas, view, layouts, read);
      case GraphMetric.best1rm:
      case GraphMetric.peakWeight:
        _line(canvas, size, view, layouts, read);
    }
    canvas.restore();
  }

  /// Every session any series in the move shows, oldest first.
  static List<GraphSession> _sessionsOf(List<_Layout> layouts) {
    if (layouts.length == 1) return layouts.single.series.sessions;
    final byId = <int, GraphSession>{
      for (final layout in layouts)
        for (final session in layout.series.sessions)
          session.sessionId: session,
    };
    return byId.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  TextPainter _text(String text, [double alpha = 1]) => TextPainter(
    text: TextSpan(
      text: text,
      style: alpha == 1
          ? tickStyle
          : tickStyle.copyWith(
              color: tickStyle.color?.withValues(
                alpha: tickStyle.color!.a * alpha,
              ),
            ),
    ),
    textDirection: TextDirection.ltr,
    textScaler: layout.textScaler,
  )..layout();

  void _axes(Canvas canvas, Size size, _View view, List<_Layout> layouts) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final ticks = <int, (double, String)>{
      for (final l in layouts)
        for (final tick in l.ticks)
          _tickKey(tick): (tick, _tickText(tick, l.step)),
    };
    for (final MapEntry(key: key, value: (tick, text)) in ticks.entries) {
      final shown = view.tickShown(key);
      if (shown <= 0) continue;
      final y = view.y(tick).roundToDouble() + 0.5;
      canvas.drawLine(
        Offset(view.plot.left, y),
        Offset(view.plot.right, y),
        Paint()
          ..color = grid.withValues(alpha: grid.a * shown)
          ..strokeWidth = 1,
      );
      final label = _text(text, shown);
      label.paint(
        canvas,
        Offset(size.width - label.width, y - label.height / 2),
      );
      label.dispose();
    }
    // Labels slide in and out under the plot's edges, never past them.
    canvas.clipRect(
      Rect.fromLTRB(
        view.plot.left - 2,
        view.plot.bottom,
        view.plot.right + 4,
        size.height,
      ),
    );
    final labels = <Object, _AxisLabel>{
      for (final l in layouts)
        for (final label in l.labels) label.key: label,
    };
    final at = <Object, double>{};
    final half = <Object, double>{};
    for (final label in labels.values) {
      at[label.key] = label.at(view);
      final text = _text(label.text);
      half[label.key] = text.width / 2;
      text.dispose();
    }
    // How much room a label has beside its neighbours of the same range: a
    // label squeezed against one fades as the gap closes, so dates thin
    // out (or fill in) as the window widens (or narrows), never piling up.
    // At rest every label has its 8 px.
    double room(Object key) {
      var most = 0.0;
      for (final l in layouts) {
        final own = l.labels;
        final i = own.indexWhere((label) => label.key == key);
        if (i < 0) continue;
        var gap = double.infinity;
        if (i > 0) {
          final before = own[i - 1].key;
          gap = (at[key]! - half[key]!) - (at[before]! + half[before]!);
        }
        if (i + 1 < own.length) {
          final after = own[i + 1].key;
          gap = math.min(
            gap,
            (at[after]! - half[after]!) - (at[key]! + half[key]!),
          );
        }
        most = math.max(most, ((gap - 2) / 6).clamp(0.0, 1.0));
      }
      return most;
    }

    for (final label in labels.values) {
      final shown = view.labelShown(label.key) * room(label.key);
      if (shown <= 0) continue;
      final text = _text(label.text, shown);
      text.paint(
        canvas,
        Offset(at[label.key]! - text.width / 2, view.plot.bottom + 7),
      );
      text.dispose();
    }
    canvas.restore();
  }

  Paint _stroke(double alpha) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = compact ? 1.75 : 2
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = ink.withValues(alpha: alpha);

  /// A dot in ink on a ring of the surface, so it reads over a line;
  /// [shown] fades both while a move brings it in or takes it away.
  void _dot(
    Canvas canvas,
    Offset center,
    double radius, [
    double alpha = 1,
    double shown = 1,
  ]) {
    if (shown <= 0) return;
    canvas.drawCircle(
      center,
      radius + (compact ? 1.5 : 2),
      Paint()..color = surface.withValues(alpha: surface.a * shown),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = ink.withValues(alpha: alpha * shown),
    );
  }

  void _readLine(Canvas canvas, _View view, double x) {
    final at = x.roundToDouble() + 0.5;
    canvas.drawLine(
      Offset(at, view.plot.top - 2),
      Offset(at, view.plot.bottom),
      Paint()
        ..color = ink
        ..strokeWidth = 1,
    );
  }

  /// Runs of segments that share one presence: (first point, last point,
  /// presence). A segment is as present as the fainter of its two ends.
  static List<(int, int, double)> _runs(List<double> shown) {
    final runs = <(int, int, double)>[];
    for (var i = 0; i + 1 < shown.length; i++) {
      final alpha = math.min(shown[i], shown[i + 1]);
      if (runs.isNotEmpty && runs.last.$3 == alpha && runs.last.$2 == i) {
        runs.last = (runs.last.$1, i + 1, alpha);
      } else {
        runs.add((i, i + 1, alpha));
      }
    }
    return runs;
  }

  Path _path(List<Offset> points, int from, int to) {
    final path = Path()..moveTo(points[from].dx, points[from].dy);
    for (var i = from + 1; i <= to; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    return path;
  }

  void _line(
    Canvas canvas,
    Size size,
    _View view,
    List<_Layout> layouts,
    int? read,
  ) {
    final sessions = _sessionsOf(layouts);
    if (sessions.isEmpty) return;
    final points = [
      for (final s in sessions) Offset(view.x(s.date), view.y(show(s.value))),
    ];
    final shown = [for (final s in sessions) view.sessionShown(s.sessionId)];
    Path washOf(Path line, int from, int to) => Path.from(line)
      ..lineTo(points[to].dx, view.plot.bottom)
      ..lineTo(points[from].dx, view.plot.bottom)
      ..close();
    Paint washPaint(double alpha) => Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, view.plot.top),
        Offset(0, view.plot.bottom),
        [ink.withValues(alpha: 0.09 * alpha), ink.withValues(alpha: 0)],
      );
    if (read == null) {
      for (final (from, to, alpha) in _runs(shown)) {
        if (alpha <= 0) continue;
        final line = _path(points, from, to);
        canvas.drawPath(washOf(line, from, to), washPaint(alpha));
        canvas.drawPath(line, _stroke(alpha));
      }
      _dot(canvas, points.last, compact ? 3.2 : 4.5, 1, shown.last);
      return;
    }
    // The line up to the point read stays; the rest steps back.
    final last = points.length - 1;
    final line = _path(points, 0, last);
    canvas.drawPath(line, _stroke(0.2));
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, points[read].dx + 0.5, size.height));
    canvas.drawPath(washOf(line, 0, last), washPaint(1));
    canvas.drawPath(line, _stroke(1));
    canvas.restore();
    _readLine(canvas, view, points[read].dx);
    _dot(canvas, points[read], 4.5);
  }

  void _staircase(Canvas canvas, _View view, List<_Layout> layouts, int? read) {
    final sessions = _sessionsOf(layouts);
    // The best before the earliest range drawn: the level the stairs start
    // at, wherever the window's left edge is.
    final outer = layouts.reduce(
      (a, b) => b.series.from.isBefore(a.series.from) ? b : a,
    );
    final before = outer.series.bestBefore;
    if (sessions.isEmpty && before == null) return;
    final dim = read != null;
    final xs = [for (final s in sessions) view.x(s.date)];
    final shown = [for (final s in sessions) view.sessionShown(s.sessionId)];

    // Each step takes the presence of the session it climbs to, so the
    // stretch a range starts with is there as long as its sessions are.
    final pieces = <(Path, double)>[];
    var best = show(before ?? sessions.first.best);
    var x = before == null || xs.isEmpty
        ? (xs.isEmpty ? view.xStart : xs.first)
        : math.min(view.xStart, xs.first);
    var alpha = shown.isEmpty ? 1.0 : shown.first;
    var path = Path()..moveTo(x, view.y(best));
    void into(double next) {
      if (next == alpha) return;
      pieces.add((path, alpha));
      path = Path()..moveTo(x, view.y(best));
      alpha = next;
    }

    for (var i = 0; i < sessions.length; i++) {
      into(shown[i]);
      final next = show(sessions[i].best);
      path.lineTo(xs[i], view.y(best));
      if (next != best) path.lineTo(xs[i], view.y(next));
      best = next;
      x = xs[i];
    }
    into(1);
    path.lineTo(view.xEnd, view.y(best));
    pieces.add((path, alpha));

    final faint = dim ? 0.14 : (compact ? 0.25 : 0.22);
    for (var i = 0; i < sessions.length; i++) {
      if (sessions[i].isRecord || shown[i] <= 0) continue;
      canvas.drawCircle(
        Offset(xs[i], view.y(show(sessions[i].value))),
        compact ? 1.6 : 2.4,
        Paint()..color = ink.withValues(alpha: faint * shown[i]),
      );
    }
    canvas.save();
    // Stairs from before the window start at its left edge.
    canvas.clipRect(
      Rect.fromLTRB(view.xStart - 1, 0, double.infinity, double.infinity),
    );
    for (final (piece, presence) in pieces) {
      if (presence <= 0) continue;
      canvas.drawPath(piece, _stroke((dim ? 0.35 : 1) * presence));
    }
    canvas.restore();
    for (var i = 0; i < sessions.length; i++) {
      if (!sessions[i].isRecord) continue;
      _dot(
        canvas,
        Offset(xs[i], view.y(show(sessions[i].value))),
        compact ? 2.4 : 3.2,
        dim ? 0.35 : 1,
        shown[i],
      );
    }
    if (read != null) {
      _readLine(canvas, view, xs[read]);
      _dot(canvas, Offset(xs[read], view.y(show(sessions[read].value))), 4.5);
    }
  }

  void _columns(Canvas canvas, _View view, List<_Layout> layouts, int? read) {
    final buckets = <_BucketKey, GraphBucket>{
      for (final l in layouts)
        if (l.series.period != null)
          for (final bucket in l.series.buckets)
            (l.series.period!, bucket.start): bucket,
    };
    if (buckets.isEmpty) return;
    final readKey = read == null
        ? null
        : (layout.series.period!, layout.series.buckets[read].start);
    final width = view.columnWidth;
    final radius = Radius.circular(math.min(4, width / 2));
    // Weeks giving way to months (or back): the new columns rise as they
    // come in, under the scale that grows or shrinks for them.
    final period = layout.series.period;
    final swapped = layouts.any((l) => l.series.period != period);
    for (final MapEntry(key: key, value: bucket) in buckets.entries) {
      if (bucket.value <= 0) continue;
      final shown = view.bucketShown(key);
      if (shown <= 0) continue;
      final x = view.column(key.$1, key.$2);
      final rise = swapped && key.$1 == period ? shown : 1.0;
      final top = math.min(
        view.y(show(bucket.value) * rise),
        view.plot.bottom - 2,
      );
      var alpha = (bucket.isCurrent ? 0.25 : 1.0) * shown;
      if (readKey != null && readKey != key) alpha *= 0.3;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(x - width / 2, top, x + width / 2, view.plot.bottom),
          topLeft: radius,
          topRight: radius,
        ),
        Paint()..color = ink.withValues(alpha: alpha),
      );
    }
    final average = view.average;
    final averageShown = view.averageShown;
    if (average != null && averageShown > 0) {
      final y = view.y(average).roundToDouble() + 0.5;
      canvas.drawLine(
        Offset(view.plot.left, y),
        Offset(view.plot.right, y),
        Paint()
          ..color = muted.withValues(alpha: muted.a * averageShown)
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_GraphPainter old) =>
      !identical(old.plan, plan) ||
      old.unit != unit ||
      old.compact != compact ||
      old.tickStyle != tickStyle ||
      old.selected != selected ||
      old.ink != ink ||
      old.surface != surface ||
      old.grid != grid ||
      old.muted != muted;
}
