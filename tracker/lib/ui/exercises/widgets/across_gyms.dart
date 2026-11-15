import 'dart:math' as math;

import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/services/gym_equivalence.dart';
import 'package:tracker/ui/core/ui/item_card.dart';
import 'package:tracker/ui/core/ui/relative_dates.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/workout/widgets/gym_factor_sheet.dart';
import 'package:tracker/ui/workout/widgets/gym_picker.dart';

/// A machine's weights across gyms: its estimated 1RM over the last year,
/// workouts elsewhere drawn as logged and as at the primary gym, on the home
/// trend; then each gym's factor, where it comes from, and a tap to set it
/// by hand. Nothing for plates and dumbbells, or with a single gym.
class AcrossGyms extends StatelessWidget {
  const AcrossGyms({
    super.key,
    required this.exercise,
    required this.sessions,
    required this.gyms,
    this.onChanged,
    this.now,
  });

  final Exercise exercise;
  final List<WorkoutSession> sessions;
  final List<Gym> gyms;

  /// A factor was set or cleared.
  final VoidCallback? onChanged;
  final DateTime? now;

  /// Whether there is anything to show for [exercise] at [gyms].
  static bool showsFor(Exercise exercise, List<Gym> gyms) =>
      convertsAcrossGyms(exercise.equipment) &&
      gyms.length > 1 &&
      gyms.any((gym) => gym.isPrimary);

  @override
  Widget build(BuildContext context) {
    if (!showsFor(exercise, gyms)) return const SizedBox.shrink();
    final theme = context.theme;
    final home = gyms.firstWhere((gym) => gym.isPrimary);
    final points = gymTrendOf(
      sessions,
      exercise.id,
      gyms,
      effectiveReps: countsEffectiveReps(context),
    );
    final shown = _lastYear(points, now ?? DateTime.now());
    final away = shown.where((point) => point.gymId != home.id);
    final muted = theme.typography.body.xs.copyWith(
      color: theme.colors.mutedForeground,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Across gyms',
          style: theme.typography.body.md.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (shown.length > 1 && away.isNotEmpty) ...[
          FCard(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Estimated 1RM, as at ${home.name}',
                    style: theme.typography.body.sm.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Workouts elsewhere are converted onto your trend at '
                    '${home.name}.',
                    style: muted,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 140,
                    child: CustomPaint(
                      painter: _TrendPainter(
                        points: shown,
                        homeGymId: home.id,
                        trend: _trendLine(points, home.id, shown),
                        unit: weightUnitOf(context),
                        ink: theme.colors.foreground,
                        faint: theme.colors.mutedForeground,
                        line: theme.colors.border,
                        paper: theme.colors.background,
                        label: theme.typography.body.xs3.copyWith(
                          color: theme.colors.mutedForeground,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _Legend(home: home.name),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        ItemCard(
          children: <FItemMixin>[
            for (final gym in gyms)
              FItem(
                key: ValueKey('across-gyms-${gym.id}'),
                prefix: Icon(
                  gym.isPrimary ? FLucideIcons.house : FLucideIcons.dumbbell,
                ),
                title: Text(gym.name, overflow: TextOverflow.ellipsis),
                subtitle: Text(gymFactorLabel(gymFactorOf(gym, exercise.id))),
                suffix: Text(
                  '×${fmtGym(gymFactorOf(gym, exercise.id).value)}',
                  style: theme.typography.body.sm.copyWith(
                    fontWeight: gym.isPrimary
                        ? FontWeight.w400
                        : FontWeight.w600,
                    color: gym.isPrimary
                        ? theme.colors.mutedForeground
                        : theme.colors.foreground,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                onPress: gym.isPrimary
                    ? null
                    : () => _adjust(context, home, gym, points),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _adjust(
    BuildContext context,
    Gym home,
    Gym gym,
    List<GymTrendPoint> points,
  ) async {
    await showGymFactorSheet(
      context,
      exerciseId: exercise.id,
      exerciseName: exercise.title,
      conversion: GymConversion(
        from: home,
        to: gym,
        fromFactor: GymFactor.home,
        toFactor: gymFactorOf(gym, exercise.id),
      ),
      fromKilograms: _lastHomeWeight(home.id),
      homeName: home.name,
    );
    onChanged?.call();
  }

  /// The heaviest working set of the latest home workout, to start the
  /// sheet from; 100 kg without one.
  double _lastHomeWeight(int homeId) {
    WorkoutSession? latest;
    for (final session in sessions) {
      if (session.gymId != homeId) continue;
      final has = session.sets.any(
        (set) =>
            set.exerciseId == exercise.id && !set.isWarmup && set.weight > 0,
      );
      if (has &&
          (latest == null || session.startTime.isAfter(latest.startTime))) {
        latest = session;
      }
    }
    var best = 0.0;
    for (final set in latest?.sets ?? const []) {
      if (set.exerciseId == exercise.id && !set.isWarmup) {
        best = math.max(best, set.weight);
      }
    }
    return best > 0 ? best : 100;
  }
}

/// Where a gym's factor for one machine comes from, in a row.
String gymFactorLabel(GymFactor factor) => switch (factor.source) {
  FactorSource.home => 'Primary, the baseline',
  FactorSource.manual => 'Set by you',
  FactorSource.estimated =>
    factor.samples == 0
        ? 'Estimated'
        : 'Estimated from ${plural('workout', factor.samples)}',
  FactorSource.gym =>
    factor.value == 1
        ? 'Not done here yet'
        : 'Not done here yet, the gym\'s overall factor',
};

/// The points of the last year, or all of them when that leaves fewer
/// than two.
List<GymTrendPoint> _lastYear(List<GymTrendPoint> points, DateTime now) {
  final from = DateTime(now.year - 1, now.month, now.day);
  final recent = [
    for (final point in points)
      if (!point.date.isBefore(from)) point,
  ];
  return recent.length > 1 ? recent : points;
}

/// The home trend across [shown]'s dates, sampled: null where no home
/// workout is near.
List<(DateTime, double?)> _trendLine(
  List<GymTrendPoint> points,
  int homeGymId,
  List<GymTrendPoint> shown,
) {
  if (shown.isEmpty) return const [];
  final first = shown.first.date;
  final span = shown.last.date.difference(first);
  const samples = 48;
  return [
    for (var i = 0; i <= samples; i++)
      () {
        final at = first.add(span * (i / samples));
        return (at, homeTrendAt(points, homeGymId, at));
      }(),
  ];
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.points,
    required this.homeGymId,
    required this.trend,
    required this.unit,
    required this.ink,
    required this.faint,
    required this.line,
    required this.paper,
    required this.label,
  });

  final List<GymTrendPoint> points;
  final int homeGymId;
  final List<(DateTime, double?)> trend;
  final WeightUnit unit;
  final Color ink;
  final Color faint;
  final Color line;
  final Color paper;
  final TextStyle label;

  static const _left = 30.0;
  static const _bottom = 16.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    var low = double.infinity;
    var high = 0.0;
    for (final point in points) {
      low = math.min(low, math.min(point.logged, point.atHome));
      high = math.max(high, math.max(point.logged, point.atHome));
    }
    for (final (_, value) in trend) {
      if (value == null) continue;
      low = math.min(low, value);
      high = math.max(high, value);
    }
    final pad = math.max((high - low) * 0.12, 1.0);
    low -= pad;
    high += pad;
    final first = points.first.date;
    final span = math.max(
      points.last.date.difference(first).inMinutes.toDouble(),
      1.0,
    );
    final width = size.width - _left;
    final height = size.height - _bottom;
    double x(DateTime date) =>
        _left + width * date.difference(first).inMinutes / span;
    double y(double value) => height * (1 - (value - low) / (high - low));

    final grid = Paint()
      ..color = line
      ..strokeWidth = 1;
    for (final share in const [0.15, 0.5, 0.85]) {
      final value = low + (high - low) * share;
      final at = y(value);
      canvas.drawLine(Offset(_left, at), Offset(size.width, at), grid);
      _text(
        canvas,
        formatDecimal(unit.fromKilograms(value).roundToDouble()),
        Offset(0, at - 6),
      );
    }
    for (final share in const [0.0, 0.5, 1.0]) {
      final date = first.add(Duration(minutes: (span * share).round()));
      final text = shortMonthName(date.month);
      final painter = _layout(text);
      final left = (x(date) - painter.width * share).clamp(
        _left,
        size.width - painter.width,
      );
      painter.paint(canvas, Offset(left, height + 3));
    }

    final trendPaint = Paint()
      ..color = ink
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    Path? path;
    for (final (date, value) in trend) {
      if (value == null) {
        if (path != null) canvas.drawPath(path, trendPaint);
        path = null;
        continue;
      }
      final offset = Offset(x(date), y(value));
      path = path == null
          ? (Path()..moveTo(offset.dx, offset.dy))
          : (path..lineTo(offset.dx, offset.dy));
    }
    if (path != null) canvas.drawPath(path, trendPaint);

    final dot = Paint()..color = ink;
    final ring = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final fill = Paint()..color = paper;
    final dashed = Paint()
      ..color = faint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final point in points) {
      final at = x(point.date);
      if (point.gymId == homeGymId) {
        canvas.drawCircle(Offset(at, y(point.logged)), 2.7, dot);
        continue;
      }
      final logged = Offset(at, y(point.logged));
      final home = Offset(at, y(point.atHome));
      _dashedLine(canvas, logged, home, dashed);
      _dashedCircle(canvas, logged, 3.8, dashed);
      canvas
        ..drawCircle(home, 3.8, fill)
        ..drawCircle(home, 3.8, ring);
    }
  }

  TextPainter _layout(String text) => TextPainter(
    text: TextSpan(text: text, style: label),
    textDirection: TextDirection.ltr,
  )..layout();

  void _text(Canvas canvas, String text, Offset at) =>
      _layout(text).paint(canvas, at);

  void _dashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    final length = (to - from).distance;
    if (length < 8) return;
    final direction = (to - from) / length;
    // Kept clear of both rings.
    for (var d = 5.0; d < length - 5; d += 4) {
      canvas.drawLine(
        from + direction * d,
        from + direction * math.min(d + 2, length - 5),
        paint,
      );
    }
  }

  void _dashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    const dashes = 8;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(
        rect,
        i * 2 * math.pi / dashes,
        math.pi / dashes,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.points != points ||
      old.trend != trend ||
      old.unit != unit ||
      old.ink != ink ||
      old.paper != paper;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.home});

  final String home;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final style = theme.typography.body.xs3.copyWith(
      color: theme.colors.mutedForeground,
    );
    Widget mark(Widget icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        icon,
        const SizedBox(width: 5),
        Text(text, style: style),
      ],
    );
    Widget circle({required bool filled, required bool dashed}) => SizedBox(
      width: 10,
      height: 10,
      child: CustomPaint(
        painter: _MarkPainter(
          filled: filled,
          dashed: dashed,
          ink: dashed ? theme.colors.mutedForeground : theme.colors.foreground,
          paper: theme.colors.background,
        ),
      ),
    );
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: <Widget>[
        mark(circle(filled: true, dashed: false), home),
        mark(circle(filled: false, dashed: true), 'Elsewhere, as logged'),
        mark(circle(filled: false, dashed: false), 'Converted'),
      ],
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({
    required this.filled,
    required this.dashed,
    required this.ink,
    required this.paper,
  });

  final bool filled;
  final bool dashed;
  final Color ink;
  final Color paper;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    if (filled) {
      canvas.drawCircle(center, 3, Paint()..color = ink);
      return;
    }
    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = dashed ? 1.2 : 1.5;
    if (!dashed) {
      canvas
        ..drawCircle(center, 3.8, Paint()..color = paper)
        ..drawCircle(center, 3.8, stroke);
      return;
    }
    final rect = Rect.fromCircle(center: center, radius: 3.8);
    for (var i = 0; i < 8; i++) {
      canvas.drawArc(rect, i * math.pi / 4, math.pi / 8, false, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _MarkPainter old) =>
      old.filled != filled ||
      old.dashed != dashed ||
      old.ink != ink ||
      old.paper != paper;
}
