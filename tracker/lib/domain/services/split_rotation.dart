import 'package:tracker/domain/models/workout_split.dart';

/// A saved session that was started from a split day.
class SplitDayVisit {
  const SplitDayVisit({
    required this.splitId,
    required this.dayIndex,
    required this.startTime,
  });

  final int splitId;
  final int dayIndex;
  final DateTime startTime;
}

/// The split day the Workout tab offers to start next.
class UpNext {
  const UpNext({
    required this.split,
    required this.dayIndex,
    this.lastDone = const {},
  });

  final WorkoutSplit split;

  /// Position of the suggested day in [split]'s days; null when it has none.
  final int? dayIndex;

  /// When each of [split]'s days (by position) was last trained.
  final Map<int, DateTime> lastDone;

  WorkoutSplitDay? get day =>
      dayIndex == null ? null : split.splitDays[dayIndex!];
}

/// The split the Workout tab trains from: [currentSplitId]'s when it still
/// exists, else the most recently trained one, else the first.
WorkoutSplit? currentSplitOf(
  List<WorkoutSplit> splits,
  List<SplitDayVisit> visits, {
  int? currentSplitId,
}) {
  if (splits.isEmpty) return null;
  final byId = {for (final split in splits) split.id: split};
  final chosen = byId[currentSplitId];
  if (chosen != null) return chosen;
  SplitDayVisit? latest;
  for (final visit in visits) {
    if (!byId.containsKey(visit.splitId)) continue;
    if (latest == null || visit.startTime.isAfter(latest.startTime)) {
      latest = visit;
    }
  }
  return latest == null ? splits.first : byId[latest.splitId];
}

/// When each split (by id) was last trained.
Map<int, DateTime> lastTrainedBySplit(List<SplitDayVisit> visits) {
  final last = <int, DateTime>{};
  for (final visit in visits) {
    final seen = last[visit.splitId];
    if (seen == null || visit.startTime.isAfter(seen)) {
      last[visit.splitId] = visit.startTime;
    }
  }
  return last;
}

/// [splits] (in saved order) as the Splits tab lists them: the current split
/// (see [currentSplitOf]) first, then the rest by when they were last used,
/// most recent first. A split is used when it is trained, and when it stops
/// being current ([usedAt], by id), so the split that was current until a
/// switch lists right below the new one. Splits never used come last, in
/// saved order.
List<WorkoutSplit> splitsByLastUsed(
  List<WorkoutSplit> splits,
  List<SplitDayVisit> visits, {
  int? currentSplitId,
  Map<int, DateTime> usedAt = const {},
}) {
  final current = currentSplitOf(
    splits,
    visits,
    currentSplitId: currentSplitId,
  );
  final trained = lastTrainedBySplit(visits);
  DateTime? lastUsed(WorkoutSplit split) {
    final a = trained[split.id];
    final b = usedAt[split.id];
    if (a == null || b == null) return a ?? b;
    return a.isAfter(b) ? a : b;
  }

  final position = {for (final (i, split) in splits.indexed) split.id: i};
  final rest = [
    for (final split in splits)
      if (split.id != current?.id) (split: split, used: lastUsed(split)),
  ];
  // Fully ordered (List.sort is not stable): last use, then saved order.
  rest.sort((a, b) {
    final (x, y) = (a.used, b.used);
    if (x != null && y != null && x != y) return y.compareTo(x);
    if ((x == null) != (y == null)) return x == null ? 1 : -1;
    return position[a.split.id]!.compareTo(position[b.split.id]!);
  });
  return [?current, for (final entry in rest) entry.split];
}

/// When each of [split]'s days (by position) was last trained.
Map<int, DateTime> lastDoneByDay(
  WorkoutSplit split,
  List<SplitDayVisit> visits,
) {
  final last = <int, DateTime>{};
  for (final visit in visits) {
    final inSplit =
        visit.splitId == split.id &&
        visit.dayIndex >= 0 &&
        visit.dayIndex < split.splitDays.length;
    if (!inSplit) continue;
    final seen = last[visit.dayIndex];
    if (seen == null || visit.startTime.isAfter(seen)) {
      last[visit.dayIndex] = visit.startTime;
    }
  }
  return last;
}

/// The next day to train: the day after the last one trained in the current
/// split (see [currentSplitOf]), wrapping around; a split never trained
/// starts at its first day.
UpNext? upNext(
  List<WorkoutSplit> splits,
  List<SplitDayVisit> visits, {
  int? currentSplitId,
}) {
  final split = currentSplitOf(splits, visits, currentSplitId: currentSplitId);
  if (split == null) return null;
  final days = split.splitDays.length;
  if (days == 0) return UpNext(split: split, dayIndex: null);
  SplitDayVisit? latest;
  for (final visit in visits) {
    if (visit.splitId != split.id || visit.dayIndex < 0) continue;
    if (latest == null || visit.startTime.isAfter(latest.startTime)) {
      latest = visit;
    }
  }
  return UpNext(
    split: split,
    dayIndex: latest == null ? 0 : (latest.dayIndex + 1) % days,
    lastDone: lastDoneByDay(split, visits),
  );
}
