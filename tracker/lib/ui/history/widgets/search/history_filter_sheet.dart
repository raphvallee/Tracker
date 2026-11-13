import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/domain/services/history_filter.dart';
import 'package:tracker/ui/core/ui/max_width.dart';
import 'package:tracker/ui/core/ui/sheet_surface.dart';
import 'package:tracker/ui/history/view_models/history_search.dart';

import 'filter_summary.dart';

/// Every History filter in one sheet, [focus] scrolled into view. The button
/// under it counts the workouts the filter shows ([countOf]) as it changes
/// and applies it; a swipe down leaves the filter as it was.
Future<HistoryFilter?> showHistoryFilterSheet(
  BuildContext context, {
  required HistorySearchData data,
  required HistoryFilter filter,
  required int Function(HistoryFilter filter) countOf,
  FilterPart? focus,
}) {
  return showFSheet<HistoryFilter>(
    context: context,
    side: .btt,
    useRootNavigator: true,
    mainAxisMaxRatio: 0.9,
    builder: builtOnce(
      (context) => HistoryFilterSheet(
        data: data,
        initial: filter,
        countOf: countOf,
        focus: focus,
      ),
    ),
  );
}

class HistoryFilterSheet extends StatefulWidget {
  const HistoryFilterSheet({
    super.key,
    required this.data,
    required this.initial,
    required this.countOf,
    this.focus,
  });

  final HistorySearchData data;
  final HistoryFilter initial;
  final int Function(HistoryFilter filter) countOf;
  final FilterPart? focus;

  @override
  State<HistoryFilterSheet> createState() => _HistoryFilterSheetState();
}

class _HistoryFilterSheetState extends State<HistoryFilterSheet> {
  /// The exercises shown before "Show all".
  static const _exercisesShown = 8;

  late HistoryFilter _filter = widget.initial;
  late int _count = widget.countOf(_filter);
  bool _allExercises = false;
  final _scroll = ScrollController();
  final _keys = {for (final part in FilterPart.values) part: GlobalKey()};

  late final List<int> _lengthCounts = _histogram(
    [for (final e in widget.data.entries) ?e.minutes],
    _lengthMax,
    _lengthBucket,
  );
  late final List<int> _setCounts = _histogram(
    [for (final e in widget.data.entries) e.workingSets],
    _setsMax,
    _setsBucket,
  );

  @override
  void initState() {
    super.initState();
    if (widget.focus case final focus?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _keys[focus]!.currentContext;
        if (target == null || !mounted) return;
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _set(HistoryFilter filter) => setState(() {
    _filter = filter;
    _count = widget.countOf(filter);
  });

  static List<int> _histogram(List<int> values, int max, int bucket) {
    final counts = List<int>.filled(max ~/ bucket + 1, 0);
    for (final value in values) {
      final at = value >= max ? counts.length - 1 : value ~/ bucket;
      counts[at]++;
    }
    return counts;
  }

  /// [set] with [value] added, or taken out when it is in.
  static Set<T> _toggled<T>(Set<T> set, T value) =>
      set.contains(value) ? ({...set}..remove(value)) : {...set, value};

  /// The splits whose days the Day part offers: the ones picked, or all.
  List<SplitOption> get _daySplits {
    final picked = _filter.splitIds.whereType<int>().toSet();
    final splits = widget.data.splits;
    return picked.isEmpty
        ? splits
        : [
            for (final split in splits)
              if (picked.contains(split.id)) split,
          ];
  }

  void _toggleSplit(int? id) {
    final splitIds = _toggled(_filter.splitIds, id);
    final kept = splitIds.whereType<int>().toSet();
    // Days of a split no longer picked could never match.
    _set(
      _filter.copyWith(
        splitIds: splitIds,
        days: kept.isEmpty
            ? _filter.days
            : {
                for (final day in _filter.days)
                  if (kept.contains(day.splitId)) day,
              },
      ),
    );
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entries = widget.data.entries;
    final first = entries.isEmpty ? today : entries.last.start;
    final from = _filter.from;
    final range = await showDateRangePicker(
      context: context,
      useRootNavigator: true,
      firstDate: DateTime(first.year, first.month, first.day),
      lastDate: today,
      initialDateRange: from == null
          ? null
          : DateTimeRange(start: from, end: _filter.to ?? from),
      helpText: 'Pick dates',
      saveText: 'Done',
    );
    if (range == null || !mounted) return;
    _set(
      _filter.copyWith(
        dates: HistoryDates.custom,
        from: range.start,
        to: range.end,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final theme = context.theme;
    final splitOptions = data.splits.length + (data.hasFreeWorkouts ? 1 : 0);
    final daySplits = _daySplits.where((s) => s.days.isNotEmpty).toList();
    final exercises = _allExercises
        ? data.exercisesByUse
        : [
            for (final (i, id) in data.exercisesByUse.indexed)
              if (i < _exercisesShown || _filter.exerciseIds.contains(id)) id,
          ];
    final hidden = data.exercisesByUse.length - exercises.length;

    return Material(
      type: MaterialType.transparency,
      child: SheetSurface(
        scrollable: true,
        controller: _scroll,
        footer: MaxWidth(
          child: FButton(
            onPress: _count == 0
                ? null
                : () => Navigator.of(context).pop(_filter),
            child: Text(
              _count == 0
                  ? 'No workouts match'
                  : 'Show ${_count == 1 ? '1 workout' : '$_count workouts'}',
            ),
          ),
        ),
        child: MaxWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Filters',
                      style: theme.typography.body.lg.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  FButton(
                    variant: .ghost,
                    size: .sm,
                    mainAxisSize: .min,
                    onPress: _filter.isEmpty
                        ? null
                        : () => _set(HistoryFilter.none),
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (splitOptions > 1)
                _Section(
                  key: _keys[FilterPart.split],
                  title: 'Split',
                  child: _Wrap(
                    children: <Widget>[
                      _Choice(
                        label: 'Any',
                        selected: _filter.splitIds.isEmpty,
                        onPress: () =>
                            _set(_filter.copyWith(splitIds: const {})),
                      ),
                      for (final split in data.splits)
                        _Choice(
                          label: split.name,
                          selected: _filter.splitIds.contains(split.id),
                          onPress: () => _toggleSplit(split.id),
                        ),
                      if (data.hasFreeWorkouts)
                        _Choice(
                          label: 'No split',
                          selected: _filter.splitIds.contains(null),
                          onPress: () => _toggleSplit(null),
                        ),
                    ],
                  ),
                ),
              if (daySplits.isNotEmpty)
                _Section(
                  key: _keys[FilterPart.day],
                  title: 'Day',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (final split in daySplits) ...[
                        // Days of several splits: each under its split.
                        if (daySplits.length > 1)
                          Padding(
                            padding: EdgeInsets.only(
                              top: split == daySplits.first ? 0 : 10,
                              bottom: 6,
                            ),
                            child: Text(
                              split.name,
                              style: theme.typography.body.xs.copyWith(
                                color: theme.colors.mutedForeground,
                              ),
                            ),
                          ),
                        _Wrap(
                          children: <Widget>[
                            for (final day in split.days)
                              _Choice(
                                label: day.name,
                                selected: _filter.days.contains((
                                  splitId: split.id,
                                  dayIndex: day.index,
                                )),
                                onPress: () => _set(
                                  _filter.copyWith(
                                    days: _toggled(_filter.days, (
                                      splitId: split.id,
                                      dayIndex: day.index,
                                    )),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              _Section(
                key: _keys[FilterPart.weekday],
                title: 'Day of the week',
                child: _Weekdays(
                  selected: _filter.weekdays,
                  onToggle: (day) => _set(
                    _filter.copyWith(weekdays: _toggled(_filter.weekdays, day)),
                  ),
                ),
              ),
              _Section(
                key: _keys[FilterPart.length],
                title: 'Length',
                value:
                    _capitalized(
                      lengthRangeLabel(_filter.minMinutes, _filter.maxMinutes),
                    ) ??
                    'Any length',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _RangeHistogram(
                      counts: _lengthCounts,
                      max: _lengthMax,
                      step: 5,
                      bucket: _lengthBucket,
                      min: _filter.minMinutes,
                      maxValue: _filter.maxMinutes,
                      scale: const ['0', '1 h', '2 h or more'],
                      semanticsLabel: 'Length in minutes',
                      onChanged: (min, max) => _set(
                        _filter.copyWith(minMinutes: min, maxMinutes: max),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _Wrap(
                      children: <Widget>[
                        for (final (min, max) in _lengthPresets)
                          _Choice(
                            label: _capitalized(lengthRangeLabel(min, max))!,
                            selected:
                                _filter.minMinutes == min &&
                                _filter.maxMinutes == max,
                            onPress: () => _set(
                              _filter.minMinutes == min &&
                                      _filter.maxMinutes == max
                                  ? _filter.copyWith(
                                      minMinutes: null,
                                      maxMinutes: null,
                                    )
                                  : _filter.copyWith(
                                      minMinutes: min,
                                      maxMinutes: max,
                                    ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              _Section(
                key: _keys[FilterPart.sets],
                title: 'Working sets',
                value:
                    _capitalized(
                      setRangeLabel(_filter.minSets, _filter.maxSets),
                    ) ??
                    'Any number',
                child: _RangeHistogram(
                  counts: _setCounts,
                  max: _setsMax,
                  step: 1,
                  bucket: _setsBucket,
                  min: _filter.minSets,
                  maxValue: _filter.maxSets,
                  scale: const ['0', '15', '30 or more'],
                  semanticsLabel: 'Working sets',
                  onChanged: (min, max) =>
                      _set(_filter.copyWith(minSets: min, maxSets: max)),
                ),
              ),
              _Section(
                key: _keys[FilterPart.dates],
                title: 'Dates',
                child: _Wrap(
                  children: <Widget>[
                    for (final (dates, label) in _datePresets)
                      _Choice(
                        label: label,
                        selected: _filter.dates == dates,
                        onPress: () => _set(
                          _filter.copyWith(dates: dates, from: null, to: null),
                        ),
                      ),
                    _Choice(
                      label:
                          _filter.hasDates &&
                              _filter.dates == HistoryDates.custom
                          ? _capitalized(
                              customDatesLabel(_filter.from!, _filter.to),
                            )!
                          : 'Pick dates',
                      selected: _filter.dates == HistoryDates.custom,
                      onPress: _pickDates,
                    ),
                  ],
                ),
              ),
              if (data.exercisesByUse.isNotEmpty)
                _Section(
                  key: _keys[FilterPart.exercises],
                  title: 'Exercises',
                  note: 'Shows workouts that include every exercise picked.',
                  child: _Wrap(
                    children: <Widget>[
                      for (final id in exercises)
                        _Choice(
                          label: data.exerciseNames[id]!,
                          selected: _filter.exerciseIds.contains(id),
                          onPress: () => _set(
                            _filter.copyWith(
                              exerciseIds: _toggled(_filter.exerciseIds, id),
                            ),
                          ),
                        ),
                      if (hidden > 0 || _allExercises)
                        FButton(
                          variant: .ghost,
                          size: .sm,
                          mainAxisSize: .min,
                          onPress: () =>
                              setState(() => _allExercises = !_allExercises),
                          child: Text(
                            _allExercises ? 'Show fewer' : 'Show $hidden more',
                          ),
                        ),
                    ],
                  ),
                ),
              if (data.gymsByUse.length > 1)
                _Section(
                  key: _keys[FilterPart.gym],
                  title: 'Gym',
                  child: _Wrap(
                    children: <Widget>[
                      _Choice(
                        label: 'Any',
                        selected: _filter.gymIds.isEmpty,
                        onPress: () => _set(_filter.copyWith(gymIds: const {})),
                      ),
                      for (final id in data.gymsByUse)
                        _Choice(
                          label: data.gymNames[id]!,
                          selected: _filter.gymIds.contains(id),
                          onPress: () => _set(
                            _filter.copyWith(
                              gymIds: _toggled(_filter.gymIds, id),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

const int _lengthMax = 120;
const int _lengthBucket = 10;
const int _setsMax = 30;
const int _setsBucket = 2;

const List<(int?, int?)> _lengthPresets = [
  (null, 45),
  (45, 60),
  (60, 90),
  (90, null),
];

const List<(HistoryDates, String)> _datePresets = [
  (HistoryDates.any, 'Any time'),
  (HistoryDates.last30Days, 'Last 30 days'),
  (HistoryDates.last3Months, 'Last 3 months'),
  (HistoryDates.thisYear, 'This year'),
];

String? _capitalized(String? text) => text == null || text.isEmpty
    ? text
    : '${text[0].toUpperCase()}${text.substring(1)}';

/// A part of the filter: its name, what it is set to on the right, the
/// controls, and a line on how it works.
class _Section extends StatelessWidget {
  const _Section({
    super.key,
    required this.title,
    this.value,
    this.note,
    required this.child,
  });

  final String title;
  final String? value;
  final String? note;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final type = theme.typography.body;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: type.sm.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (value case final value?)
                Text(
                  value,
                  style: type.xs.copyWith(
                    color: theme.colors.mutedForeground,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          child,
          if (note case final note?) ...[
            const SizedBox(height: 6),
            Text(
              note,
              style: type.xs.copyWith(color: theme.colors.mutedForeground),
            ),
          ],
        ],
      ),
    );
  }
}

class _Wrap extends StatelessWidget {
  const _Wrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 6, runSpacing: 6, children: children);
}

/// An option of the filter: outlined, or filled in ink when picked.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onPress,
    this.semanticsLabel,
    this.center = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onPress;
  final String? semanticsLabel;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return FTappable(
      selected: selected,
      semanticsLabel: semanticsLabel ?? label,
      onPress: onPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        constraints: const BoxConstraints(minHeight: 36),
        alignment: center ? Alignment.center : null,
        padding: EdgeInsets.symmetric(horizontal: center ? 2 : 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colors.foreground : colors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? colors.foreground : colors.border,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.theme.typography.body.sm.copyWith(
            fontWeight: FontWeight.w500,
            height: 1.25,
            color: selected ? colors.background : colors.foreground,
          ),
        ),
      ),
    );
  }
}

/// The days of the week as a row of seven equal tiles.
class _Weekdays extends StatelessWidget {
  const _Weekdays({required this.selected, required this.onToggle});

  static const _short = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _long = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final Set<int> selected;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (var day = DateTime.monday; day <= DateTime.sunday; day++) ...[
          if (day != DateTime.monday) const SizedBox(width: 5),
          Expanded(
            child: _Choice(
              label: _short[day - 1],
              semanticsLabel: _long[day - 1],
              selected: selected.contains(day),
              center: true,
              onPress: () => onToggle(day),
            ),
          ),
        ],
      ],
    );
  }
}

/// A range slider over bars of how many workouts fall at each value, so
/// the usual values are easy to find. The top of the scale means "or more";
/// an end at the edge of the scale is open (null).
class _RangeHistogram extends StatelessWidget {
  const _RangeHistogram({
    required this.counts,
    required this.max,
    required this.step,
    required this.bucket,
    required this.min,
    required this.maxValue,
    required this.scale,
    required this.semanticsLabel,
    required this.onChanged,
  });

  /// Workouts per [bucket] of values; the last one holds [max] and above.
  final List<int> counts;
  final int max;
  final int step;
  final int bucket;
  final int? min;
  final int? maxValue;
  final List<String> scale;
  final String semanticsLabel;
  final void Function(int? min, int? max) onChanged;

  /// Whether bar [i] holds values in [low] to [high] ([high] at the top of
  /// the scale has no end).
  bool _inRange(int i, int low, int high) {
    final last = i == counts.length - 1;
    final start = i * bucket;
    final end = last ? null : start + bucket;
    return (high == max || start <= high) && (end == null || end > low);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = theme.colors;
    final low = (min ?? 0).clamp(0, max);
    final high = (maxValue ?? max).clamp(low, max);
    final most = counts.fold<int>(1, (a, b) => a > b ? a : b);
    // The thumbs sit [_inset] in from the edges: the bars line up with them.
    const inset = 12.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: inset),
            child: SizedBox(
              height: 40,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  for (final (i, count) in counts.indexed) ...[
                    if (i > 0) const SizedBox(width: 3),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        height: count == 0 ? 2 : 2 + 38 * count / most,
                        decoration: BoxDecoration(
                          color: _inRange(i, low, high)
                              ? colors.foreground
                              : colors.border,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            activeTrackColor: colors.foreground,
            inactiveTrackColor: colors.border,
            thumbColor: colors.foreground,
            overlayColor: colors.foreground.withValues(alpha: 0.08),
            activeTickMarkColor: Colors.transparent,
            inactiveTickMarkColor: Colors.transparent,
            rangeThumbShape: const RoundRangeSliderThumbShape(
              enabledThumbRadius: 9,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            padding: const EdgeInsets.symmetric(horizontal: inset),
          ),
          child: SizedBox(
            height: 36,
            child: RangeSlider(
              values: RangeValues(low.toDouble(), high.toDouble()),
              max: max.toDouble(),
              divisions: max ~/ step,
              semanticFormatterCallback: (value) =>
                  '$semanticsLabel ${value.round()}${value.round() == max ? ' or more' : ''}',
              onChanged: (values) {
                final start = values.start.round();
                final end = values.end.round();
                onChanged(start == 0 ? null : start, end == max ? null : end);
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: inset - 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              for (final label in scale)
                Text(
                  label,
                  style: theme.typography.body.xs.copyWith(
                    fontSize: 11,
                    color: colors.mutedForeground,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
