import 'package:tracker/domain/services/history_filter.dart';
import 'package:tracker/ui/core/ui/relative_dates.dart';
import 'package:tracker/ui/history/view_models/history_search.dart';

/// The parts of the filter sheet, in its order.
enum FilterPart { split, day, weekday, length, sets, dates, exercises, gym }

/// A run of the filter read back as a sentence; [part] is set on the words
/// that say what one part of the filter is set to.
typedef SummaryPiece = ({String text, FilterPart? part});

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// "a", "a or b", "a, b or c".
String joinWords(List<String> words, String last) => switch (words.length) {
  0 => '',
  1 => words.single,
  _ => '${words.take(words.length - 1).join(', ')} $last ${words.last}',
};

/// "45 min to 1 h 30 min", "1 h or more", "up to 45 min"; null when both
/// ends are open.
String? lengthRangeLabel(int? min, int? max) {
  String length(int minutes) =>
      minutes == 0 ? '0 min' : lengthLabel(Duration(minutes: minutes));
  return switch ((min, max)) {
    (null, null) => null,
    (final min?, null) => '${length(min)} or more',
    (null, final max?) => 'up to ${length(max)}',
    (final min?, final max?) when min == max => length(min),
    (final min?, final max?) => '${length(min)} to ${length(max)}',
  };
}

/// "10 to 20 working sets", "15 or more", "up to 10"; null when both ends
/// are open.
String? setRangeLabel(int? min, int? max) {
  String sets(int n) => n == 1 ? '1 working set' : '$n working sets';
  return switch ((min, max)) {
    (null, null) => null,
    (final min?, null) => '$min or more working sets',
    (null, final max?) => 'up to ${sets(max)}',
    (final min?, final max?) when min == max => sets(min),
    (final min?, final max?) => '$min to ${sets(max)}',
  };
}

/// "in the last 30 days", "this year", "from 3 Oct to 9 Nov"; null for any
/// time.
String? datesLabel(HistoryFilter filter) {
  if (!filter.hasDates) return null;
  return switch (filter.dates) {
    HistoryDates.any => null,
    HistoryDates.last30Days => 'in the last 30 days',
    HistoryDates.last3Months => 'in the last 3 months',
    HistoryDates.thisYear => 'this year',
    HistoryDates.custom => customDatesLabel(filter.from!, filter.to),
  };
}

/// A picked date range in words: "on 9 Nov" for one day, else "from 3 Oct
/// to 9 Nov", with the year when it is not this one.
String customDatesLabel(DateTime from, DateTime? to, {DateTime? now}) {
  final year = (now ?? DateTime.now()).year;
  String date(DateTime d) =>
      d.year == year ? dayMonthLabel(d) : '${dayMonthLabel(d)} ${d.year}';
  final last = to ?? from;
  if (last.year == from.year &&
      last.month == from.month &&
      last.day == from.day) {
    return 'on ${date(from)}';
  }
  return 'from ${date(from)} to ${date(last)}';
}

/// The day names of [filter], each once.
List<String> dayNamesOf(HistoryFilter filter, HistorySearchData data) => [
  ...{for (final key in filter.days) data.dayName(key)},
];

/// The filter read back as one sentence, starting with how many workouts
/// it shows and, with a search typed, what it was read as: "9 workouts
/// matching Squat, from Push Pull Legs, on Tuesdays and Fridays, lasting 1 h
/// or more."
List<SummaryPiece> filterSummary(
  HistoryFilter filter,
  HistorySearchData data, {
  required int count,
  String? matching,
}) {
  final pieces = <SummaryPiece>[
    (text: count == 1 ? '1 workout' : '$count workouts', part: null),
    if (matching != null && matching.isNotEmpty)
      (text: ' matching $matching', part: null),
  ];
  final lead = pieces.length;
  void add(String word, String? words, FilterPart part) {
    if (words == null || words.isEmpty) return;
    pieces
      ..add((text: pieces.length == lead ? ' $word ' : ', $word ', part: null))
      ..add((text: words, part: part));
  }

  if (filter.splitIds.isNotEmpty) {
    final names = [
      for (final split in data.splits)
        if (filter.splitIds.contains(split.id)) split.name,
    ];
    final free = filter.splitIds.contains(null);
    if (names.isEmpty && free) {
      pieces
        ..add((text: pieces.length == lead ? ' ' : ', ', part: null))
        ..add((text: 'without a split', part: FilterPart.split));
    } else {
      add(
        'from',
        joinWords([...names, if (free) 'no split'], 'or'),
        FilterPart.split,
      );
    }
  }
  if (filter.days.isNotEmpty) {
    final names = dayNamesOf(filter, data);
    add('on', '${joinWords(names, 'or')} days', FilterPart.day);
  }
  if (filter.weekdays.isNotEmpty) {
    final days = filter.weekdays.toList()..sort();
    add(
      'on',
      joinWords([for (final d in days) '${_weekdayNames[d - 1]}s'], 'and'),
      FilterPart.weekday,
    );
  }
  add(
    'lasting',
    lengthRangeLabel(filter.minMinutes, filter.maxMinutes),
    FilterPart.length,
  );
  add('with', setRangeLabel(filter.minSets, filter.maxSets), FilterPart.sets);
  if (datesLabel(filter) case final dates?) {
    pieces
      ..add((text: pieces.length == lead ? ' ' : ', ', part: null))
      ..add((text: dates, part: FilterPart.dates));
  }
  if (filter.exerciseIds.isNotEmpty) {
    add(
      'with',
      joinWords([
        for (final id in data.exercisesByUse)
          if (filter.exerciseIds.contains(id)) data.exerciseNames[id]!,
      ], 'and'),
      FilterPart.exercises,
    );
  }
  if (filter.gymIds.isNotEmpty) {
    add(
      'at',
      joinWords([
        for (final id in data.gymsByUse)
          if (filter.gymIds.contains(id)) data.gymNames[id]!,
      ], 'or'),
      FilterPart.gym,
    );
  }
  pieces.add((text: '.', part: null));
  return pieces;
}
