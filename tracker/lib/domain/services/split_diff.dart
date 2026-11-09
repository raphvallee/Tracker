import 'package:tracker/domain/models/split_draft.dart';

enum SplitChangeKind { added, removed, changed, moved }

/// One difference between a saved split and its draft, worded for people.
class SplitChange {
  const SplitChange({
    required this.kind,
    required this.title,
    this.group,
    this.before,
    this.after,
    this.detail,
  });

  final SplitChangeKind kind;

  /// The day the change belongs to (its draft title); null for changes to
  /// the split itself (its name, description and days).
  final String? group;

  final String title;

  /// The saved value and the draft's, when the change replaces one.
  final String? before;
  final String? after;

  final String? detail;
}

/// Every change between a saved split ([diffSplit]'s `base`) and its draft,
/// plus which draft days, exercises and sets they touch.
class SplitDiff {
  SplitDiff._(this.changes);

  final List<SplitChange> changes;

  /// Draft day indexes that were added, or changed in any way.
  final Set<int> newDays = {};
  final Set<int> changedDays = {};

  /// Saved day indexes that are gone from the draft.
  final List<int> removedDays = [];

  /// Per draft day index: draft exercise indexes added or changed.
  final Map<int, Set<int>> newExercises = {};
  final Map<int, Set<int>> changedExercises = {};

  /// Per draft day index: saved exercise indexes gone from the draft day.
  final Map<int, List<int>> removedExercises = {};

  /// Per draft day, per draft exercise: set indexes that changed or are new.
  final Map<int, Map<int, Set<int>>> changedSets = {};

  int get count => changes.length;

  bool get isEmpty => changes.isEmpty;

  bool isNewExercise(int day, int exercise) =>
      newExercises[day]?.contains(exercise) ?? false;

  bool isChangedExercise(int day, int exercise) =>
      changedExercises[day]?.contains(exercise) ?? false;

  bool isChangedSet(int day, int exercise, int set) =>
      newDays.contains(day) ||
      isNewExercise(day, exercise) ||
      (changedSets[day]?[exercise]?.contains(set) ?? false);
}

/// "1st", "2nd", "3rd", "4th", "11th", "22nd".
String ordinal(int n) {
  final lastTwo = n % 100;
  if (lastTwo >= 11 && lastTwo <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}

String _exercises(int n) => n == 1 ? '1 exercise' : '$n exercises';

String _lowerFirst(String text) =>
    text.isEmpty ? text : '${text[0].toLowerCase()}${text.substring(1)}';

/// Compares [draft] with the saved split it was made from ([base]).
/// [nameOf] names an exercise by id.
SplitDiff diffSplit(
  SplitDraft base,
  SplitDraft draft, {
  required String Function(int exerciseId) nameOf,
}) {
  final changes = <SplitChange>[];
  final diff = SplitDiff._(changes);

  if (base.title != draft.title) {
    changes.add(
      SplitChange(
        kind: SplitChangeKind.changed,
        title: 'Renamed split',
        before: base.title,
        after: draft.title,
      ),
    );
  }
  if (base.description != draft.description) {
    changes.add(
      SplitChange(
        kind: SplitChangeKind.changed,
        title: 'Split description',
        before: base.description.isEmpty ? 'None' : base.description,
        after: draft.description.isEmpty ? 'None' : draft.description,
      ),
    );
  }

  final keptDays = {
    for (final day in draft.days)
      if (day.origin != null) day.origin!,
  };
  for (var i = 0; i < base.days.length; i++) {
    if (keptDays.contains(i)) continue;
    diff.removedDays.add(i);
    changes.add(
      SplitChange(
        kind: SplitChangeKind.removed,
        title: 'Removed ${base.days[i].title}',
        detail: 'It had ${_exercises(base.days[i].exercises.length)}',
      ),
    );
  }

  final movedDays = _moved([
    for (final day in draft.days) (origin: day.origin, dragged: day.reordered),
  ]);
  final dayChanges = <SplitChange>[];
  for (var i = 0; i < draft.days.length; i++) {
    final day = draft.days[i];
    final origin = day.origin;
    if (origin == null || origin >= base.days.length) {
      diff
        ..newDays.add(i)
        ..changedDays.add(i);
      changes.add(
        SplitChange(
          kind: SplitChangeKind.added,
          title: 'Added ${day.title}',
          detail:
              '${_exercises(day.exercises.length)}, ${ordinal(i + 1)} in the '
              'split',
        ),
      );
      continue;
    }
    if (movedDays.contains(i)) {
      diff.changedDays.add(i);
      changes.add(
        _move(
          title: 'Moved ${day.title}',
          from: origin,
          to: i,
          below: () => draft.days[i - 1].title,
        ),
      );
    }
    final before = dayChanges.length;
    _diffDay(diff, dayChanges, i, base.days[origin], day, nameOf);
    if (dayChanges.length > before) diff.changedDays.add(i);
  }
  changes.addAll(dayChanges);
  return diff;
}

void _diffDay(
  SplitDiff diff,
  List<SplitChange> changes,
  int dayIndex,
  DayDraft baseDay,
  DayDraft day,
  String Function(int exerciseId) nameOf,
) {
  final group = day.title;
  if (baseDay.title != day.title) {
    changes.add(
      SplitChange(
        kind: SplitChangeKind.changed,
        group: group,
        title: 'Renamed day',
        before: baseDay.title,
        after: day.title,
      ),
    );
  }
  if (baseDay.description != day.description) {
    changes.add(
      SplitChange(
        kind: SplitChangeKind.changed,
        group: group,
        title: 'Day description',
        before: baseDay.description.isEmpty ? 'None' : baseDay.description,
        after: day.description.isEmpty ? 'None' : day.description,
      ),
    );
  }

  final kept = {
    for (final exercise in day.exercises)
      if (exercise.origin != null) exercise.origin!,
  };
  for (var j = 0; j < baseDay.exercises.length; j++) {
    if (kept.contains(j)) continue;
    final gone = baseDay.exercises[j];
    (diff.removedExercises[dayIndex] ??= []).add(j);
    changes.add(
      SplitChange(
        kind: SplitChangeKind.removed,
        group: group,
        title: 'Removed ${nameOf(gone.exerciseId)}',
        detail: 'It had ${_lowerFirst(setsSummary(gone.sets))}',
      ),
    );
  }

  final moved = _moved([
    for (final exercise in day.exercises)
      (origin: exercise.origin, dragged: exercise.reordered),
  ]);
  for (var k = 0; k < day.exercises.length; k++) {
    final exercise = day.exercises[k];
    final name = nameOf(exercise.exerciseId);
    final origin = exercise.origin;
    if (origin == null || origin >= baseDay.exercises.length) {
      (diff.newExercises[dayIndex] ??= {}).add(k);
      changes.add(
        SplitChange(
          kind: SplitChangeKind.added,
          group: group,
          title: 'Added $name',
          detail: '${setsSummary(exercise.sets)}, ${ordinal(k + 1)} in the day',
        ),
      );
      continue;
    }
    if (moved.contains(k)) {
      (diff.changedExercises[dayIndex] ??= {}).add(k);
      changes.add(
        _move(
          group: group,
          title: 'Moved $name',
          from: origin,
          to: k,
          below: () => nameOf(day.exercises[k - 1].exerciseId),
        ),
      );
    }
    final saved = baseDay.exercises[origin].sets;
    final sets = exercise.sets;
    for (var s = 0; s < saved.length || s < sets.length; s++) {
      final SplitChange change;
      if (s >= saved.length) {
        change = SplitChange(
          kind: SplitChangeKind.added,
          group: group,
          title: '$name, added set ${s + 1}',
          detail: sets[s].description,
        );
      } else if (s >= sets.length) {
        change = SplitChange(
          kind: SplitChangeKind.removed,
          group: group,
          title: '$name, removed set ${s + 1}',
          detail: 'It was ${saved[s].description}',
        );
      } else if (saved[s] != sets[s]) {
        change = SplitChange(
          kind: SplitChangeKind.changed,
          group: group,
          title: '$name, set ${s + 1}',
          before: saved[s].description,
          after: sets[s].description,
        );
      } else {
        continue;
      }
      changes.add(change);
      (diff.changedExercises[dayIndex] ??= {}).add(k);
      if (s < sets.length) {
        ((diff.changedSets[dayIndex] ??= {})[k] ??= {}).add(s);
      }
    }
  }
}

/// A move from saved position [from] to draft position [to]. When both read
/// the same (items came and went around it), it says what the item now sits
/// below instead: [below] names the item right above it.
SplitChange _move({
  String? group,
  required String title,
  required int from,
  required int to,
  required String Function() below,
}) => from == to && to > 0
    ? SplitChange(
        kind: SplitChangeKind.moved,
        group: group,
        title: title,
        detail: 'Now below ${below()}',
      )
    : SplitChange(
        kind: SplitChangeKind.moved,
        group: group,
        title: title,
        before: ordinal(from + 1),
        after: ordinal(to + 1),
      );

/// Draft positions of kept items (non-null origin) that moved: every kept
/// item outside one run that still follows the saved order. The run keeps
/// as many items nobody dragged as it can, then as many dragged ones as
/// fit, so a drag past a neighbour is reported as the item dragged, never
/// as the neighbour it pushed aside.
Set<int> _moved(List<({int? origin, bool dragged})> items) {
  final kept = [
    for (var i = 0; i < items.length; i++)
      if (items[i].origin != null) i,
  ];
  if (kept.length < 2) return {};
  // Best increasing run of the kept origins ending at each kept item,
  // O(n^2): lists here are a handful of days or exercises. A run scores by
  // the undragged items it keeps, then by its length.
  final undragged = List.filled(kept.length, 0);
  final length = List.filled(kept.length, 0);
  final previous = List.filled(kept.length, -1);
  bool beats(int u, int l, int than) =>
      u > undragged[than] || (u == undragged[than] && l > length[than]);
  var best = 0;
  for (var a = 0; a < kept.length; a++) {
    final own = items[kept[a]].dragged ? 0 : 1;
    undragged[a] = own;
    length[a] = 1;
    for (var b = 0; b < a; b++) {
      final follows = items[kept[b]].origin! < items[kept[a]].origin!;
      if (follows && beats(undragged[b] + own, length[b] + 1, a)) {
        undragged[a] = undragged[b] + own;
        length[a] = length[b] + 1;
        previous[a] = b;
      }
    }
    if (beats(undragged[a], length[a], best)) best = a;
  }
  final stayed = <int>{};
  for (var at = best; at != -1; at = previous[at]) {
    stayed.add(kept[at]);
  }
  return {
    for (final index in kept)
      if (!stayed.contains(index)) index,
  };
}
