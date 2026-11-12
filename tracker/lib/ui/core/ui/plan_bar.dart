import 'dart:math' as math;

import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/ui/core/themes/accents.dart';

/// One exercise on the [PlanBar].
class PlanSegment {
  const PlanSegment({
    required this.sets,
    this.progress = 0,
    this.isCurrent = false,
  });

  /// Its working sets: how wide the segment is next to the others.
  final int sets;

  /// How much of it is logged, from 0 to 1.
  final double progress;

  /// The exercise being done: its track stands out from the ones waiting.
  final bool isCurrent;
}

/// The workout as one bar: a segment per exercise, as wide as its sets,
/// filling as they are logged. The same bar before the workout (empty: the
/// shape of the day), on the exercise list and on each exercise. A finished
/// workout's bar is drawn in [ink]: it is a record, not a live workout.
class PlanBar extends StatelessWidget {
  const PlanBar({super.key, required this.segments, this.ink = false});

  final List<PlanSegment> segments;

  /// Fills in the foreground color instead of the live accent.
  final bool ink;

  static const double height = 6;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final fill = ink
        ? colors.foreground.withValues(alpha: 0.8)
        : TrackerAccents.of(context).live;
    // Stronger than the muted fill: before a workout the whole bar is
    // empty, and its shape is the point.
    Color track(double strength) => Color.alphaBlend(
      colors.mutedForeground.withValues(alpha: strength),
      colors.muted,
    );
    return ExcludeSemantics(
      child: Row(
        children: <Widget>[
          for (final (i, segment) in segments.indexed) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              flex: math.max(segment.sets, 1),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(height / 2),
                child: SizedBox(
                  height: height,
                  child: ColoredBox(
                    color: track(segment.isCurrent ? 0.4 : 0.12),
                    child: FractionallySizedBox(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: segment.progress.clamp(0.0, 1.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: fill,
                          borderRadius: BorderRadius.circular(height / 2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
