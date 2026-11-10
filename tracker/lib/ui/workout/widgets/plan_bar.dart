import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/ui/core/themes/accents.dart';

import 'workout_entries.dart';

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

/// The running workout's exercises as segments; [current] is the one being
/// done. An exercise with no planned sets is as wide as one set.
List<PlanSegment> planSegments(List<WorkoutEntry> entries, {int? current}) => [
  for (final (i, entry) in entries.indexed)
    PlanSegment(
      sets: entry.planned,
      progress: entry.progress,
      isCurrent: i == current,
    ),
];

/// The workout as one bar: a segment per exercise, as wide as its sets,
/// filling as they are logged. The same bar before the workout (empty: the
/// shape of the day), on the exercise list and on each exercise.
class PlanBar extends StatelessWidget {
  const PlanBar({super.key, required this.segments});

  final List<PlanSegment> segments;

  static const double height = 6;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final accents = TrackerAccents.of(context);
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
                          color: accents.live,
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
