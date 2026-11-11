import 'package:tracker/ui/core/ui/plan_bar.dart';

import 'workout_entries.dart';

export 'package:tracker/ui/core/ui/plan_bar.dart';

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
