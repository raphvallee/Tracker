import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/domain/services/history_filter.dart';

/// A split History can be narrowed to, with the days of it that were
/// trained, in the split's order.
class SplitOption {
  const SplitOption({required this.id, required this.name, required this.days});

  final int id;
  final String name;
  final List<({int index, String name})> days;
}

/// Everything History's search and filters read, read at once when search
/// opens: every workout, and the names each one is found and filtered by.
/// Only what was trained is offered: a split, day, exercise or gym no
/// workout used would only ever show an empty list.
class HistorySearchData {
  HistorySearchData._({
    required this.entries,
    required this.sessions,
    required this.exerciseNames,
    required this.gymNames,
    required this.splits,
    required this.hasFreeWorkouts,
    required this.exercisesByUse,
    required this.gymsByUse,
  });

  /// Reads every workout of [repo], newest first.
  factory HistorySearchData.read(TrackerRepository repo) {
    final sessions = repo.sessions.getAllSync();
    final splits = {for (final s in repo.splits.getAllSync()) s.id: s};
    final gymNames = {for (final g in repo.gyms.getAllSync()) g.id: g.name};
    final exerciseNames = repo.exercises.getTitlesSync({
      for (final session in sessions)
        for (final set in session.sets) set.exerciseId,
    });

    final exerciseUse = <int, int>{};
    final gymUse = <int, int>{};
    final trainedDays = <int, Set<int>>{};
    var hasFree = false;
    final entries = <HistoryEntry>[];
    for (final session in sessions) {
      final split = splits[session.splitId];
      final day = _dayOf(split, session.splitDayIndex);
      final entry = HistoryEntry.of(
        session,
        splitName: split?.title,
        dayName: day?.title,
        gymName: gymNames[session.gymId],
        exerciseNames: exerciseNames,
      );
      entries.add(entry);
      for (final id in entry.exerciseIds) {
        exerciseNames[id] ??= 'Exercise $id';
        exerciseUse[id] = (exerciseUse[id] ?? 0) + 1;
      }
      if (session.gymId case final gym? when gymNames.containsKey(gym)) {
        gymUse[gym] = (gymUse[gym] ?? 0) + 1;
      }
      if (session.splitId == null) {
        hasFree = true;
      } else if (split != null) {
        final days = trainedDays.putIfAbsent(split.id, () => <int>{});
        if (day != null) days.add(session.splitDayIndex!);
      }
    }

    List<int> byUse(Map<int, int> use, String Function(int) name) =>
        use.keys.toList()..sort((a, b) {
          final byCount = use[b]!.compareTo(use[a]!);
          return byCount != 0 ? byCount : name(a).compareTo(name(b));
        });

    return HistorySearchData._(
      entries: entries,
      sessions: {for (final session in sessions) session.id: session},
      exerciseNames: exerciseNames,
      gymNames: gymNames,
      splits: [
        for (final split in splits.values)
          if (trainedDays[split.id] case final days?)
            SplitOption(
              id: split.id,
              name: split.title,
              days: [
                for (final (index, day) in split.splitDays.indexed)
                  if (days.contains(index)) (index: index, name: day.title),
              ],
            ),
      ],
      hasFreeWorkouts: hasFree,
      exercisesByUse: byUse(exerciseUse, (id) => exerciseNames[id]!),
      gymsByUse: byUse(gymUse, (id) => gymNames[id]!),
    );
  }

  static final empty = HistorySearchData._(
    entries: const [],
    sessions: const {},
    exerciseNames: const {},
    gymNames: const {},
    splits: const [],
    hasFreeWorkouts: false,
    exercisesByUse: const [],
    gymsByUse: const [],
  );

  static WorkoutSplitDay? _dayOf(WorkoutSplit? split, int? index) {
    if (split == null || index == null) return null;
    if (index < 0 || index >= split.splitDays.length) return null;
    return split.splitDays[index];
  }

  /// Every workout, newest first.
  final List<HistoryEntry> entries;
  final Map<int, WorkoutSession> sessions;
  final Map<int, String> exerciseNames;
  final Map<int, String> gymNames;

  /// Splits trained from, in the Splits tab's order.
  final List<SplitOption> splits;

  /// Whether some workout was started without a split.
  final bool hasFreeWorkouts;

  /// Exercises logged, the most often logged first.
  final List<int> exercisesByUse;

  /// Gyms trained at, the most often used first.
  final List<int> gymsByUse;

  String splitName(int id) =>
      [
        for (final split in splits)
          if (split.id == id) split.name,
      ].firstOrNull ??
      'Split';

  String dayName(SplitDayKey key) =>
      [
        for (final split in splits)
          if (split.id == key.splitId)
            for (final day in split.days)
              if (day.index == key.dayIndex) day.name,
      ].firstOrNull ??
      'Day';

  /// The names a search can read as: exercises, splits, days and gyms.
  Iterable<String> get names sync* {
    for (final id in exercisesByUse) {
      yield exerciseNames[id]!;
    }
    for (final split in splits) {
      yield split.name;
      for (final day in split.days) {
        yield day.name;
      }
    }
    for (final id in gymsByUse) {
      yield gymNames[id]!;
    }
  }
}
