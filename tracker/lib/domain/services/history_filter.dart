import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/services/fuzzy_search.dart';
import 'package:tracker/domain/services/session_summary.dart';

/// One finished workout as History's search sees it: what it can be found
/// by, read once when search opens.
class HistoryEntry {
  HistoryEntry({
    required this.id,
    required this.start,
    required this.end,
    required this.title,
    required this.splitId,
    required this.dayIndex,
    required this.gymId,
    required this.exerciseIds,
    required this.workingSets,
    required this.words,
  });

  /// [session] with the names it is searched by: its split's and split
  /// day's, its gym's and its exercises' ([exerciseNames] by id).
  factory HistoryEntry.of(
    WorkoutSession session, {
    String? splitName,
    String? dayName,
    String? gymName,
    required Map<int, String> exerciseNames,
  }) {
    final exerciseIds = [
      for (final group in groupByExercise(session.sets)) group.exerciseId,
    ];
    return HistoryEntry(
      id: session.id,
      start: session.startTime,
      end: session.endTime,
      title: session.title,
      splitId: session.splitId,
      dayIndex: session.splitId == null ? null : session.splitDayIndex,
      gymId: session.gymId,
      exerciseIds: exerciseIds,
      workingSets: workingSetCount(session.sets),
      words: {
        ...searchWords(session.title),
        ...searchWords(splitName ?? ''),
        ...searchWords(dayName ?? ''),
        ...searchWords(gymName ?? ''),
        for (final id in exerciseIds) ...searchWords(exerciseNames[id] ?? ''),
      },
    );
  }

  final int id;
  final DateTime start;
  final DateTime? end;
  final String title;
  final int? splitId;
  final int? dayIndex;
  final int? gymId;

  /// Its exercises in the order they were first logged.
  final List<int> exerciseIds;
  final int workingSets;

  /// Every word it can be searched by.
  final Set<String> words;

  /// How long it took, in whole minutes; null while it has no end.
  int? get minutes {
    final end = this.end;
    if (end == null) return null;
    final length = end.difference(start).inMinutes;
    return length < 0 ? 0 : length;
  }
}

/// A split day: the split's id and the day's position in it.
typedef SplitDayKey = ({int splitId, int dayIndex});

/// The date ranges History can be narrowed to.
enum HistoryDates { any, last30Days, last3Months, thisYear, custom }

/// What History is narrowed to. Each part left empty or null lets every
/// workout through; a workout shows when it passes every part set.
class HistoryFilter {
  const HistoryFilter({
    this.splitIds = const {},
    this.days = const {},
    this.weekdays = const {},
    this.minMinutes,
    this.maxMinutes,
    this.minSets,
    this.maxSets,
    this.dates = HistoryDates.any,
    this.from,
    this.to,
    this.exerciseIds = const {},
    this.gymIds = const {},
  });

  /// Splits to show; null stands for workouts started without one.
  final Set<int?> splitIds;
  final Set<SplitDayKey> days;

  /// [DateTime.monday] to [DateTime.sunday].
  final Set<int> weekdays;

  /// How long, in minutes, both ends included; null leaves an end open.
  final int? minMinutes;
  final int? maxMinutes;

  /// How many working sets, both ends included; null leaves an end open.
  final int? minSets;
  final int? maxSets;

  final HistoryDates dates;

  /// The first and last day of a [HistoryDates.custom] range.
  final DateTime? from;
  final DateTime? to;

  /// Exercises a workout must all hold.
  final Set<int> exerciseIds;
  final Set<int> gymIds;

  static const HistoryFilter none = HistoryFilter();

  bool get hasLength => minMinutes != null || maxMinutes != null;
  bool get hasSets => minSets != null || maxSets != null;
  bool get hasDates =>
      dates != HistoryDates.any &&
      (dates != HistoryDates.custom || from != null);

  /// How many parts are set: the count on the filter button.
  int get activeCount => [
    splitIds.isNotEmpty,
    days.isNotEmpty,
    weekdays.isNotEmpty,
    hasLength,
    hasSets,
    hasDates,
    exerciseIds.isNotEmpty,
    gymIds.isNotEmpty,
  ].where((set) => set).length;

  bool get isEmpty => activeCount == 0;

  /// The first moment in range and the first one after it, for [now].
  ({DateTime? from, DateTime? until}) dateRange(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (dates) {
      HistoryDates.any => (from: null, until: null),
      HistoryDates.last30Days => (
        from: DateTime(today.year, today.month, today.day - 29),
        until: null,
      ),
      HistoryDates.last3Months => (
        from: DateTime(today.year, today.month - 3, today.day),
        until: null,
      ),
      HistoryDates.thisYear => (from: DateTime(today.year), until: null),
      HistoryDates.custom => (
        from: from,
        until: switch (to ?? from) {
          final last? => DateTime(last.year, last.month, last.day + 1),
          null => null,
        },
      ),
    };
  }

  /// Whether [entry] passes every part set; [now] places the date presets.
  bool matches(HistoryEntry entry, DateTime now) {
    if (splitIds.isNotEmpty && !splitIds.contains(entry.splitId)) return false;
    if (days.isNotEmpty) {
      final split = entry.splitId;
      final day = entry.dayIndex;
      if (split == null || day == null) return false;
      if (!days.contains((splitId: split, dayIndex: day))) return false;
    }
    if (weekdays.isNotEmpty && !weekdays.contains(entry.start.weekday)) {
      return false;
    }
    if (hasLength) {
      final minutes = entry.minutes;
      if (minutes == null) return false;
      if (minMinutes case final min? when minutes < min) return false;
      if (maxMinutes case final max? when minutes > max) return false;
    }
    if (minSets case final min? when entry.workingSets < min) return false;
    if (maxSets case final max? when entry.workingSets > max) return false;
    if (hasDates) {
      final range = dateRange(now);
      if (range.from case final from? when entry.start.isBefore(from)) {
        return false;
      }
      if (range.until case final until? when !entry.start.isBefore(until)) {
        return false;
      }
    }
    if (exerciseIds.isNotEmpty &&
        !exerciseIds.every(entry.exerciseIds.contains)) {
      return false;
    }
    if (gymIds.isNotEmpty && !gymIds.contains(entry.gymId)) return false;
    return true;
  }

  HistoryFilter copyWith({
    Set<int?>? splitIds,
    Set<SplitDayKey>? days,
    Set<int>? weekdays,
    Object? minMinutes = _keep,
    Object? maxMinutes = _keep,
    Object? minSets = _keep,
    Object? maxSets = _keep,
    HistoryDates? dates,
    Object? from = _keep,
    Object? to = _keep,
    Set<int>? exerciseIds,
    Set<int>? gymIds,
  }) => HistoryFilter(
    splitIds: splitIds ?? this.splitIds,
    days: days ?? this.days,
    weekdays: weekdays ?? this.weekdays,
    minMinutes: minMinutes == _keep ? this.minMinutes : minMinutes as int?,
    maxMinutes: maxMinutes == _keep ? this.maxMinutes : maxMinutes as int?,
    minSets: minSets == _keep ? this.minSets : minSets as int?,
    maxSets: maxSets == _keep ? this.maxSets : maxSets as int?,
    dates: dates ?? this.dates,
    from: from == _keep ? this.from : from as DateTime?,
    to: to == _keep ? this.to : to as DateTime?,
    exerciseIds: exerciseIds ?? this.exerciseIds,
    gymIds: gymIds ?? this.gymIds,
  );
}

const Object _keep = Object();

/// [entries] that [query] finds and [filter] lets through, in their order.
List<HistoryEntry> searchHistory(
  List<HistoryEntry> entries, {
  required FuzzyQuery query,
  required HistoryFilter filter,
  required DateTime now,
}) => [
  for (final entry in entries)
    if (filter.matches(entry, now) &&
        (query.isEmpty || query.findsAll(entry.words)))
      entry,
];

/// The one name [query] reads as, from [names] (exercises, splits, days,
/// gyms): of the names all its words find, the one with the fewest words,
/// when no other ties it. "bech pres" reads as "Bench Press", not
/// "Incline Bench Press"; null when nothing, or more than one name, fits.
String? nameQueryReadsAs(FuzzyQuery query, Iterable<String> names) {
  if (query.isEmpty) return null;
  String? best;
  var bestWords = 0;
  var tied = false;
  for (final name in {...names}) {
    final words = searchWords(name);
    if (words.length < query.words.length || !query.findsAll(words)) continue;
    if (best == null || words.length < bestWords) {
      best = name;
      bestWords = words.length;
      tied = false;
    } else if (words.length == bestWords && name != best) {
      tied = true;
    }
  }
  return tied ? null : best;
}
