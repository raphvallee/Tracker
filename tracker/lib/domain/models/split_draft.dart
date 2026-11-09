import 'package:tracker/domain/models/workout_split.dart';

/// A planned set's rep target: fixed reps ([maxReps] null) or a range, for
/// a working set or a [warmup].
class SetTarget {
  const SetTarget(this.minReps, [this.maxReps]) : warmup = false;

  const SetTarget.warmup(this.minReps, [this.maxReps]) : warmup = true;

  /// Ranges whose max does not exceed the min read as fixed reps.
  factory SetTarget.fromPlanned(PlannedSet set) => SetTarget(
    set.minReps,
    set.maxReps != null && set.maxReps! > set.minReps ? set.maxReps : null,
  ).withWarmup(set.isWarmup);

  static SetTarget? fromJson(Object? json) {
    if (json is! List || json.isEmpty || json.first is! int) return null;
    final min = json.first as int;
    final max = json.length > 1 && json[1] is int ? json[1] as int : null;
    if (min < 1) return null;
    return SetTarget(
      min,
      max != null && max > min ? max : null,
    ).withWarmup(json.length > 2 && json[2] == true);
  }

  final int minReps;
  final int? maxReps;

  /// Not one of the exercise's working sets.
  final bool warmup;

  bool get isRange => maxReps != null;

  String get label => maxReps == null ? '$minReps' : '$minReps-$maxReps';

  String get unit => !isRange && minReps == 1 ? 'rep' : 'reps';

  /// "8-12 reps", "1 rep", "10 warm-up reps".
  String get description => warmup ? '$label warm-up $unit' : '$label $unit';

  SetTarget withWarmup(bool warmup) =>
      warmup ? SetTarget.warmup(minReps, maxReps) : SetTarget(minReps, maxReps);

  PlannedSet toPlanned(int order) => PlannedSet(
    order: order,
    minReps: minReps,
    maxReps: maxReps,
    isWarmup: warmup,
  );

  List<Object?> toJson() => [minReps, maxReps, if (warmup) true];

  @override
  bool operator ==(Object other) =>
      other is SetTarget &&
      minReps == other.minReps &&
      maxReps == other.maxReps &&
      warmup == other.warmup;

  @override
  int get hashCode => Object.hash(minReps, maxReps, warmup);
}

/// "3 sets of 8-12 reps", or every target in order when they differ; warm-ups
/// lead: "2 warm-ups, then 3 sets of 8-12 reps".
String setsSummary(List<SetTarget> sets) {
  if (sets.isEmpty) return 'No sets';
  final warmups = [
    for (final set in sets)
      if (set.warmup) set,
  ];
  final working = [
    for (final set in sets)
      if (!set.warmup) set,
  ];
  if (warmups.isEmpty) return _summary(working, 'set');
  if (working.isEmpty) return _summary(warmups, 'warm-up');
  final count = warmups.length == 1
      ? '1 warm-up'
      : '${warmups.length} warm-ups';
  return '$count, then ${_summary(working, 'set')}';
}

String _summary(List<SetTarget> sets, String noun) {
  final count = sets.length == 1 ? '1 $noun' : '${sets.length} ${noun}s';
  if (sets.every((set) => set == sets.first)) {
    return '$count of ${sets.first.label} ${sets.first.unit}';
  }
  return '$count: ${sets.map((set) => set.label).join(', ')} reps';
}

/// One exercise of a [DayDraft].
class ExerciseDraft {
  const ExerciseDraft({
    required this.exerciseId,
    this.origin,
    this.reordered = false,
    this.sets = const [],
    this.targetSets,
    this.targetReps,
    this.restSeconds,
  });

  factory ExerciseDraft.fromJson(Map<String, dynamic> json) => ExerciseDraft(
    exerciseId: json['exerciseId'] is int ? json['exerciseId'] as int : 0,
    origin: json['origin'] is int ? json['origin'] as int : null,
    reordered: json['reordered'] == true,
    sets: json['sets'] is List
        ? (json['sets'] as List)
              .map(SetTarget.fromJson)
              .whereType<SetTarget>()
              .toList(growable: false)
        : const [],
    targetSets: json['targetSets'] is int ? json['targetSets'] as int : null,
    targetReps: json['targetReps'] is int ? json['targetReps'] as int : null,
    restSeconds: json['restSeconds'] is int ? json['restSeconds'] as int : null,
  );

  final int exerciseId;

  /// Position in the saved day this exercise came from; null when it was
  /// added in the draft.
  final int? origin;

  /// Dragged to another place in the draft. A hint for the review, not
  /// content (equality ignores it): when a move reads two ways, as when two
  /// neighbours swap, the review names the exercise that was dragged.
  final bool reordered;

  final List<SetTarget> sets;

  // Legacy plan fields, carried through untouched.
  final int? targetSets;
  final int? targetReps;
  final int? restSeconds;

  ExerciseDraft copyWith({List<SetTarget>? sets, bool? reordered}) =>
      ExerciseDraft(
        exerciseId: exerciseId,
        origin: origin,
        reordered: reordered ?? this.reordered,
        sets: sets ?? this.sets,
        targetSets: targetSets,
        targetReps: targetReps,
        restSeconds: restSeconds,
      );

  ExerciseDraft withSet(int index, SetTarget target) {
    if (index < 0 || index >= sets.length) return this;
    return copyWith(sets: [...sets]..[index] = target);
  }

  /// Adds a working set copying the last one's reps ([fallback] when there
  /// is none).
  ExerciseDraft addSet(SetTarget fallback) => copyWith(
    sets: [...sets, (sets.isEmpty ? fallback : sets.last).withWarmup(false)],
  );

  ExerciseDraft removeSet(int index) {
    if (index < 0 || index >= sets.length || sets.length <= 1) return this;
    return copyWith(sets: [...sets]..removeAt(index));
  }

  /// Every set of [target]'s type (warm-up or working) takes its reps.
  ExerciseDraft withRepsForType(SetTarget target) => copyWith(
    sets: [
      for (final set in sets)
        if (set.warmup == target.warmup) target else set,
    ],
  );

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'origin': origin,
    'reordered': reordered,
    'sets': [for (final set in sets) set.toJson()],
    'targetSets': targetSets,
    'targetReps': targetReps,
    'restSeconds': restSeconds,
  };

  @override
  bool operator ==(Object other) =>
      other is ExerciseDraft &&
      exerciseId == other.exerciseId &&
      origin == other.origin &&
      targetSets == other.targetSets &&
      targetReps == other.targetReps &&
      restSeconds == other.restSeconds &&
      _listEquals(sets, other.sets);

  @override
  int get hashCode => Object.hash(
    exerciseId,
    origin,
    targetSets,
    targetReps,
    restSeconds,
    Object.hashAll(sets),
  );
}

/// One day of a [SplitDraft].
class DayDraft {
  const DayDraft({
    required this.title,
    this.origin,
    this.reordered = false,
    this.description = '',
    this.exercises = const [],
  });

  factory DayDraft.fromJson(Map<String, dynamic> json) => DayDraft(
    title: json['title'] is String ? json['title'] as String : '',
    origin: json['origin'] is int ? json['origin'] as int : null,
    reordered: json['reordered'] == true,
    description: json['description'] is String
        ? json['description'] as String
        : '',
    exercises: json['exercises'] is List
        ? (json['exercises'] as List)
              .whereType<Map>()
              .map((e) => ExerciseDraft.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false)
        : const [],
  );

  /// Position in the saved split this day came from; null when it was added
  /// in the draft.
  final int? origin;

  /// Dragged to another place in the draft; see [ExerciseDraft.reordered].
  final bool reordered;

  final String title;
  final String description;
  final List<ExerciseDraft> exercises;

  int get setCount =>
      exercises.fold(0, (total, exercise) => total + exercise.sets.length);

  DayDraft copyWith({
    String? title,
    String? description,
    List<ExerciseDraft>? exercises,
    bool? reordered,
  }) => DayDraft(
    origin: origin,
    reordered: reordered ?? this.reordered,
    title: title ?? this.title,
    description: description ?? this.description,
    exercises: exercises ?? this.exercises,
  );

  DayDraft addExercise(int exerciseId, List<SetTarget> sets) => copyWith(
    exercises: [
      ...exercises,
      ExerciseDraft(exerciseId: exerciseId, sets: sets),
    ],
  );

  DayDraft removeExercise(int index) {
    if (index < 0 || index >= exercises.length) return this;
    return copyWith(exercises: [...exercises]..removeAt(index));
  }

  /// Puts back the exercise [baseDay] holds at [origin], among the kept
  /// exercises that came before it in the saved day.
  DayDraft restoreExercise(DayDraft baseDay, int origin) {
    if (origin < 0 || origin >= baseDay.exercises.length) return this;
    if (exercises.any((exercise) => exercise.origin == origin)) return this;
    final at = exercises
        .where((e) => e.origin != null && e.origin! < origin)
        .length;
    final index = _insertionIndex(exercises.map((e) => e.origin), at);
    return copyWith(
      exercises: [...exercises]..insert(index, baseDay.exercises[origin]),
    );
  }

  /// [newIndex] is the index after removing the moved exercise, which is
  /// marked [ExerciseDraft.reordered].
  DayDraft reorderExercise(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= exercises.length) return this;
    final list = [...exercises];
    final moved = list.removeAt(oldIndex);
    final at = newIndex.clamp(0, list.length);
    if (at == oldIndex) return this;
    list.insert(at, moved.copyWith(reordered: true));
    return copyWith(exercises: list);
  }

  DayDraft updateExercise(
    int index,
    ExerciseDraft Function(ExerciseDraft exercise) change,
  ) {
    if (index < 0 || index >= exercises.length) return this;
    return copyWith(
      exercises: [...exercises]..[index] = change(exercises[index]),
    );
  }

  Map<String, dynamic> toJson() => {
    'origin': origin,
    'reordered': reordered,
    'title': title,
    'description': description,
    'exercises': [for (final exercise in exercises) exercise.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      other is DayDraft &&
      origin == other.origin &&
      title == other.title &&
      description == other.description &&
      _listEquals(exercises, other.exercises);

  @override
  int get hashCode =>
      Object.hash(origin, title, description, Object.hashAll(exercises));
}

/// An editable copy of a saved split. Days and exercises remember where they
/// sat in the saved split ([DayDraft.origin], [ExerciseDraft.origin]), so the
/// draft can be compared with it change by change.
class SplitDraft {
  const SplitDraft({
    required this.splitId,
    required this.title,
    this.description = '',
    this.days = const [],
  });

  /// [fallback] seeds exercises saved before planned sets existed: their old
  /// set count with their old reps (or [fallback]'s), else one [fallback] set.
  factory SplitDraft.fromSplit(
    WorkoutSplit split, {
    SetTarget fallback = const SetTarget(8, 12),
  }) => SplitDraft(
    splitId: split.id,
    title: split.title,
    description: split.description,
    days: [
      for (final (i, day) in split.splitDays.indexed)
        DayDraft(
          origin: i,
          title: day.title,
          description: day.description,
          exercises: [
            for (final (j, item) in day.exercises.indexed)
              ExerciseDraft(
                exerciseId: item.exerciseId,
                origin: j,
                sets: _seededSets(item, fallback),
                targetSets: item.targetSets,
                targetReps: item.targetReps,
                restSeconds: item.restSeconds,
              ),
          ],
        ),
    ],
  );

  factory SplitDraft.fromJson(Map<String, dynamic> json) => SplitDraft(
    splitId: json['splitId'] is int ? json['splitId'] as int : 0,
    title: json['title'] is String ? json['title'] as String : '',
    description: json['description'] is String
        ? json['description'] as String
        : '',
    days: json['days'] is List
        ? (json['days'] as List)
              .whereType<Map>()
              .map((d) => DayDraft.fromJson(Map<String, dynamic>.from(d)))
              .toList(growable: false)
        : const [],
  );

  final int splitId;
  final String title;
  final String description;
  final List<DayDraft> days;

  SplitDraft copyWith({
    String? title,
    String? description,
    List<DayDraft>? days,
  }) => SplitDraft(
    splitId: splitId,
    title: title ?? this.title,
    description: description ?? this.description,
    days: days ?? this.days,
  );

  SplitDraft addDay(String title) => copyWith(
    days: [
      ...days,
      DayDraft(title: title),
    ],
  );

  SplitDraft removeDay(int index) {
    if (index < 0 || index >= days.length) return this;
    return copyWith(days: [...days]..removeAt(index));
  }

  /// Puts back the day [base] holds at [origin], among the kept days that
  /// came before it in the saved split.
  SplitDraft restoreDay(SplitDraft base, int origin) {
    if (origin < 0 || origin >= base.days.length) return this;
    if (days.any((day) => day.origin == origin)) return this;
    final at = days.where((d) => d.origin != null && d.origin! < origin).length;
    final index = _insertionIndex(days.map((d) => d.origin), at);
    return copyWith(days: [...days]..insert(index, base.days[origin]));
  }

  /// [newIndex] is the index after removing the moved day, which is marked
  /// [DayDraft.reordered].
  SplitDraft reorderDay(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= days.length) return this;
    final list = [...days];
    final moved = list.removeAt(oldIndex);
    final at = newIndex.clamp(0, list.length);
    if (at == oldIndex) return this;
    list.insert(at, moved.copyWith(reordered: true));
    return copyWith(days: list);
  }

  SplitDraft updateDay(int index, DayDraft Function(DayDraft day) change) {
    if (index < 0 || index >= days.length) return this;
    return copyWith(days: [...days]..[index] = change(days[index]));
  }

  /// Writes this draft's content into [split], keeping its id and order.
  void writeTo(WorkoutSplit split) {
    split
      ..title = title
      ..description = description
      ..splitDays = [
        for (final (i, day) in days.indexed)
          WorkoutSplitDay(
            title: day.title,
            description: day.description,
            order: i,
            exercises: [
              for (final (j, exercise) in day.exercises.indexed)
                ExerciseItem(
                  exerciseId: exercise.exerciseId,
                  order: j,
                  targetSets: exercise.targetSets,
                  targetReps: exercise.targetReps,
                  restSeconds: exercise.restSeconds,
                  sets: [
                    for (final (k, set) in exercise.sets.indexed)
                      set.toPlanned(k),
                  ],
                ),
            ],
          ),
      ];
  }

  Map<String, dynamic> toJson() => {
    'splitId': splitId,
    'title': title,
    'description': description,
    'days': [for (final day in days) day.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      other is SplitDraft &&
      splitId == other.splitId &&
      title == other.title &&
      description == other.description &&
      _listEquals(days, other.days);

  @override
  int get hashCode =>
      Object.hash(splitId, title, description, Object.hashAll(days));
}

List<SetTarget> _seededSets(ExerciseItem item, SetTarget fallback) {
  if (item.sets.isNotEmpty) {
    return [for (final set in item.sets) SetTarget.fromPlanned(set)];
  }
  final count = item.targetSets ?? 0;
  final legacy = (item.targetReps ?? 0) > 0
      ? SetTarget(item.targetReps!)
      : null;
  return List.filled(count > 0 ? count : 1, legacy ?? fallback);
}

/// The list index right after the first [keptBefore] kept items (items with
/// a non-null origin).
int _insertionIndex(Iterable<int?> origins, int keptBefore) {
  var kept = 0;
  var index = 0;
  for (final origin in origins) {
    if (kept == keptBefore) break;
    if (origin != null) kept++;
    index++;
  }
  return index;
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
