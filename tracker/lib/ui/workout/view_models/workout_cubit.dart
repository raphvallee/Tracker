import 'dart:collection';

import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/data/services/app_log.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/domain/services/analytics.dart';

class ActiveSet {
  const ActiveSet({
    required this.exerciseId,
    required this.exerciseName,
    this.weight = 0,
    this.reps = 0,
    this.type = SetType.working,
    this.order = 0,
  });

  factory ActiveSet.fromJson(Map<String, dynamic> json) => ActiveSet(
    exerciseId: _intValue(json['exerciseId']),
    exerciseName: json['exerciseName'] is String
        ? json['exerciseName'] as String
        : '',
    weight: _doubleValue(json['weight']),
    reps: _doubleValue(json['reps']),
    type: SetType.values.asNameMap()[json['type']] ?? SetType.working,
    order: _intValue(json['order']),
  );

  @override
  bool operator ==(Object other) =>
      other is ActiveSet &&
      exerciseId == other.exerciseId &&
      exerciseName == other.exerciseName &&
      weight == other.weight &&
      reps == other.reps &&
      type == other.type &&
      order == other.order;

  @override
  int get hashCode =>
      Object.hash(exerciseId, exerciseName, weight, reps, type, order);
  final int exerciseId;
  final String exerciseName;
  final double weight;
  final double reps;
  final SetType type;
  final int order;

  bool get isWarmup => type == SetType.warmup;

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'exerciseName': exerciseName,
    'weight': weight,
    'reps': reps,
    'type': type.name,
    'order': order,
  };

  static int _intValue(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  static double _doubleValue(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}

class PlanExercise {
  const PlanExercise({
    required this.exerciseId,
    required this.name,
    this.order = 0,
    this.sets = const [],
  });

  factory PlanExercise.fromJson(Map<String, dynamic> json) {
    // Bind to a local first: type promotion lets `.whereType().map()` dispatch
    // statically (a dynamic receiver would erase the type argument and yield
    // a List<dynamic> that fails the parameter check).
    final rawSets = json['sets'];
    return PlanExercise(
      exerciseId: _intValue(json['exerciseId']),
      name: json['name'] is String ? json['name'] as String : '',
      order: _intValue(json['order']),
      // `sets` is newer than the v1 hydration payload; older snapshots without
      // it restore with no plan (the form simply stays empty).
      sets: rawSets is List
          ? rawSets
                .whereType<Map>()
                .map(_plannedSetFromJson)
                .toList(growable: false)
          : const [],
    );
  }

  static PlannedSet _plannedSetFromJson(Map<dynamic, dynamic> json) =>
      PlannedSet(
        order: _intValue(json['order']),
        minReps: _intValue(json['minReps']),
        maxReps: _intValueOrNull(json['maxReps']),
      );

  static int _intValue(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  static int? _intValueOrNull(Object? value) => value is num
      ? value.toInt()
      : value is String
      ? int.tryParse(value)
      : null;

  @override
  bool operator ==(Object other) =>
      other is PlanExercise &&
      exerciseId == other.exerciseId &&
      name == other.name &&
      order == other.order &&
      _listEquals(sets, other.sets);

  @override
  int get hashCode =>
      Object.hash(exerciseId, name, order, Object.hashAll(sets));
  final int exerciseId;
  final String name;
  final int order;
  final List<PlannedSet> sets;

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'name': name,
    'order': order,
    'sets': [
      for (final set in sets)
        {'order': set.order, 'minReps': set.minReps, 'maxReps': set.maxReps},
    ],
  };
}

bool _listEquals(List<PlannedSet> a, List<PlannedSet> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].minReps != b[i].minReps || a[i].maxReps != b[i].maxReps) {
      return false;
    }
  }
  return true;
}

Map<int, List<ActiveSet>> _groupSets(List<ActiveSet> sets) {
  final grouped = <int, List<ActiveSet>>{};
  for (final set in sets) {
    (grouped[set.exerciseId] ??= <ActiveSet>[]).add(set);
  }
  return grouped;
}

List<PlanExercise> _parsePlan(Object? raw) => raw is List
    ? raw
          .whereType<Map>()
          .map((entry) {
            try {
              return PlanExercise.fromJson(Map<String, dynamic>.from(entry));
            } catch (_) {
              return null;
            }
          })
          .whereType<PlanExercise>()
          .toList(growable: false)
    : const [];

List<ActiveSet> _parseSets(Object? raw) => raw is List
    ? raw
          .whereType<Map>()
          .map((entry) {
            try {
              return ActiveSet.fromJson(Map<String, dynamic>.from(entry));
            } catch (_) {
              return null;
            }
          })
          .whereType<ActiveSet>()
          .toList(growable: false)
    : const [];

final _setsByExerciseCache = Expando<Map<int, List<ActiveSet>>>();
final _workingVolumeCache = Expando<double>();

class WorkoutSnapshot {
  const WorkoutSnapshot({
    required this.startTime,
    this.gymId,
    this.gymName,
    this.planTitle,
    this.splitTitle,
    this.splitId,
    this.splitDayIndex,
    this.plan = const [],
    this.sets = const [],
  });

  factory WorkoutSnapshot.fromState(WorkoutState state) => WorkoutSnapshot(
    startTime: state.startTime ?? DateTime.now(),
    gymId: state.gymId,
    gymName: state.gymName,
    planTitle: state.planTitle,
    splitTitle: state.splitTitle,
    splitId: state.splitId,
    splitDayIndex: state.splitDayIndex,
    plan: state.plan,
    sets: state.sets,
  );

  factory WorkoutSnapshot.fromJson(Map<String, dynamic> json) {
    return WorkoutSnapshot(
      startTime: json['startTime'] is String
          ? (DateTime.tryParse(json['startTime'] as String) ?? DateTime.now())
          : DateTime.now(),
      gymId: WorkoutState._nullableInt(json['gymId']),
      gymName: json['gymName'] is String ? json['gymName'] as String : null,
      planTitle: json['planTitle'] is String
          ? json['planTitle'] as String
          : null,
      splitTitle: json['splitTitle'] is String
          ? json['splitTitle'] as String
          : null,
      splitId: WorkoutState._nullableInt(json['splitId']),
      splitDayIndex: WorkoutState._nullableInt(json['splitDayIndex']),
      plan: _parsePlan(json['plan']),
      sets: _parseSets(json['sets']),
    );
  }

  final DateTime startTime;

  final int? gymId;
  final String? gymName;

  final String? planTitle;
  final String? splitTitle;
  final int? splitId;
  final int? splitDayIndex;
  final List<PlanExercise> plan;
  final List<ActiveSet> sets;

  Map<String, dynamic> toJson() => {
    'startTime': startTime.toIso8601String(),
    'gymId': gymId,
    'gymName': gymName,
    'planTitle': planTitle,
    'splitTitle': splitTitle,
    'splitId': splitId,
    'splitDayIndex': splitDayIndex,
    'plan': plan.map((e) => e.toJson()).toList(),
    'sets': sets.map((s) => s.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is WorkoutSnapshot &&
      startTime == other.startTime &&
      gymId == other.gymId &&
      gymName == other.gymName &&
      planTitle == other.planTitle &&
      splitTitle == other.splitTitle &&
      splitId == other.splitId &&
      splitDayIndex == other.splitDayIndex &&
      WorkoutState._listEquals(plan, other.plan) &&
      WorkoutState._listEquals(sets, other.sets);

  @override
  int get hashCode => Object.hash(
    startTime,
    gymId,
    gymName,
    planTitle,
    splitTitle,
    splitId,
    splitDayIndex,
    Object.hashAll(plan),
    Object.hashAll(sets),
  );
}

class WorkoutState {
  WorkoutState({
    required this.isInProgress,
    this.startTime,
    this.gymId,
    this.gymName,
    this.planTitle,
    this.splitTitle,
    this.splitId,
    this.splitDayIndex,
    this.lastGymId,
    this.saveError,
    this.savedSnapshot,
    this.savedSessionId,
    this.savedAt,
    this.discardedSnapshot,
    this.discardedAt,
    List<PlanExercise> plan = const [],
    List<ActiveSet> sets = const [],
  }) : _plan = List.unmodifiable(plan),
       _sets = List.unmodifiable(sets);

  factory WorkoutState.fromJson(Map<String, dynamic> json) {
    // Hydrated-state schema versioning (PRODUCTION_READINESS.md Phase 1).
    // v1 = the original shape; v2 adds the restorable last-saved snapshot;
    // v3 adds the split link, the split title and the last gym.
    // Payloads written before versioning have no 'v' key and read as v1.
    // Unknown future versions fall back to a clean idle state instead of
    // crashing.
    switch (json['v'] as int? ?? 1) {
      case 1:
        return _fromV1(json);
      case 2:
        return _fromV2(json);
      case 3:
        return _fromV3(json);
      default:
        return WorkoutState.initial();
    }
  }

  static WorkoutState _fromV2(Map<String, dynamic> json) {
    final rawSaved = json['saved'];
    return _fromV1(json).copyWith(
      savedSnapshot: rawSaved is Map
          ? WorkoutSnapshot.fromJson(Map<String, dynamic>.from(rawSaved))
          : null,
      savedSessionId: _nullableInt(json['savedSessionId']),
      savedAt: json['savedAt'] is String
          ? DateTime.tryParse(json['savedAt'] as String)
          : null,
    );
  }

  static WorkoutState _fromV3(Map<String, dynamic> json) =>
      _fromV2(json).copyWith(
        splitTitle: json['splitTitle'] is String
            ? json['splitTitle'] as String
            : null,
        splitId: _nullableInt(json['splitId']),
        splitDayIndex: _nullableInt(json['splitDayIndex']),
        lastGymId: _nullableInt(json['lastGymId']),
      );

  static WorkoutState _fromV1(Map<String, dynamic> json) {
    return WorkoutState(
      isInProgress: json['isInProgress'] is bool
          ? json['isInProgress'] as bool
          : false,
      startTime: json['startTime'] is String
          ? DateTime.tryParse(json['startTime'] as String)
          : null,
      gymId: _nullableInt(json['gymId']),
      gymName: json['gymName'] is String ? json['gymName'] as String : null,
      planTitle: json['planTitle'] is String
          ? json['planTitle'] as String
          : null,
      plan: _parsePlan(json['plan']),
      sets: _parseSets(json['sets']),
    );
  }

  static int? _nullableInt(Object? value) => value is num
      ? value.toInt()
      : value is String
      ? int.tryParse(value)
      : null;

  final List<PlanExercise> _plan;
  final List<ActiveSet> _sets;

  List<PlanExercise> get plan => _plan;

  List<ActiveSet> get sets => _sets;

  final bool isInProgress;
  final DateTime? startTime;

  final int? gymId;
  final String? gymName;

  final String? planTitle;

  /// Title of the split a plan workout came from; [planTitle] holds the day.
  final String? splitTitle;

  /// The split and day (by position) a plan workout was started from.
  final int? splitId;
  final int? splitDayIndex;

  /// The gym the next workout starts at; survives the workout ending.
  final int? lastGymId;

  /// Set when the final Isar write in [WorkoutCubit.endWorkout] failed. Purely
  /// transient UI feedback - deliberately excluded from hydration JSON, so a
  /// restarted app never boots into a stale error banner.
  final String? saveError;

  final WorkoutSnapshot? savedSnapshot;
  final int? savedSessionId;

  final DateTime? savedAt;

  /// Snapshot of the last discarded workout and when it was discarded. Purely
  /// in-memory - like web sessionStorage, deliberately excluded from hydration
  /// JSON so it never survives an app restart. Restorable only within
  /// [discardRestoreWindow] of [discardedAt].
  final WorkoutSnapshot? discardedSnapshot;
  final DateTime? discardedAt;

  static const Duration discardRestoreWindow = Duration(minutes: 15);

  bool canRestoreSaved({DateTime? now}) {
    if (isInProgress || savedSnapshot == null) return false;
    final at = now ?? DateTime.now();
    if (savedAt == null) return true; // backward compatibility for old payloads
    return at.difference(savedAt!) < discardRestoreWindow;
  }

  bool canRestoreDiscarded({DateTime? now}) {
    if (isInProgress || discardedSnapshot == null || discardedAt == null) {
      return false;
    }
    final at = now ?? DateTime.now();
    return at.difference(discardedAt!) < discardRestoreWindow;
  }

  /// Lazily groups the active sets for the presentation layer.
  ///
  /// The grouping is cached per immutable state instance, so rendering a plan
  /// does not repeatedly scan all sets once per exercise card. This is derived
  /// state only; it is intentionally not included in hydration serialization.
  Map<int, List<ActiveSet>> get setsByExercise =>
      _setsByExerciseCache[this] ??= UnmodifiableMapView(
        _groupSets(sets)
            .map((key, value) => MapEntry(key, List.unmodifiable(value))),
      );

  @override
  bool operator ==(Object other) =>
      other is WorkoutState &&
      isInProgress == other.isInProgress &&
      startTime == other.startTime &&
      gymId == other.gymId &&
      gymName == other.gymName &&
      planTitle == other.planTitle &&
      splitTitle == other.splitTitle &&
      splitId == other.splitId &&
      splitDayIndex == other.splitDayIndex &&
      lastGymId == other.lastGymId &&
      saveError == other.saveError &&
      savedSnapshot == other.savedSnapshot &&
      savedSessionId == other.savedSessionId &&
      savedAt == other.savedAt &&
      discardedSnapshot == other.discardedSnapshot &&
      discardedAt == other.discardedAt &&
      _listEquals(plan, other.plan) &&
      _listEquals(sets, other.sets);

  @override
  int get hashCode => Object.hash(
    isInProgress,
    startTime,
    gymId,
    gymName,
    planTitle,
    splitTitle,
    splitId,
    splitDayIndex,
    lastGymId,
    saveError,
    savedSnapshot,
    savedSessionId,
    savedAt,
    discardedSnapshot,
    discardedAt,
    Object.hashAll(plan),
    Object.hashAll(sets),
  );

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  double get workingVolume => _workingVolumeCache[this] ??= sets
      .where((set) => !set.isWarmup)
      .fold<double>(0, (total, set) => total + set.weight * set.reps);

  static WorkoutState initial() => WorkoutState(isInProgress: false);

  Map<String, dynamic> toJson() => {
    'v': 3,
    'isInProgress': isInProgress,
    'startTime': startTime?.toIso8601String(),
    'gymId': gymId,
    'gymName': gymName,
    'planTitle': planTitle,
    'splitTitle': splitTitle,
    'splitId': splitId,
    'splitDayIndex': splitDayIndex,
    'lastGymId': lastGymId,
    'plan': plan.map((e) => e.toJson()).toList(),
    'sets': sets.map((s) => s.toJson()).toList(),
    // Restorable last-saved workout (v2). The discarded snapshot is
    // deliberately omitted: it is in-memory only, like web sessionStorage.
    'saved': savedSnapshot?.toJson(),
    'savedSessionId': savedSessionId,
    'savedAt': savedAt?.toIso8601String(),
  };

  WorkoutState copyWith({
    bool? isInProgress,
    Object? startTime = _unset,
    Object? gymId = _unset,
    Object? gymName = _unset,
    Object? planTitle = _unset,
    Object? splitTitle = _unset,
    Object? splitId = _unset,
    Object? splitDayIndex = _unset,
    Object? lastGymId = _unset,
    Object? saveError = _unset,
    Object? savedSnapshot = _unset,
    Object? savedSessionId = _unset,
    Object? savedAt = _unset,
    Object? discardedSnapshot = _unset,
    Object? discardedAt = _unset,
    List<PlanExercise>? plan,
    List<ActiveSet>? sets,
  }) {
    return WorkoutState(
      isInProgress: isInProgress ?? this.isInProgress,
      startTime: identical(startTime, _unset)
          ? this.startTime
          : startTime as DateTime?,
      gymId: identical(gymId, _unset) ? this.gymId : gymId as int?,
      gymName: identical(gymName, _unset) ? this.gymName : gymName as String?,
      planTitle: identical(planTitle, _unset)
          ? this.planTitle
          : planTitle as String?,
      splitTitle: identical(splitTitle, _unset)
          ? this.splitTitle
          : splitTitle as String?,
      splitId: identical(splitId, _unset) ? this.splitId : splitId as int?,
      splitDayIndex: identical(splitDayIndex, _unset)
          ? this.splitDayIndex
          : splitDayIndex as int?,
      lastGymId: identical(lastGymId, _unset)
          ? this.lastGymId
          : lastGymId as int?,
      saveError: identical(saveError, _unset)
          ? this.saveError
          : saveError as String?,
      savedSnapshot: identical(savedSnapshot, _unset)
          ? this.savedSnapshot
          : savedSnapshot as WorkoutSnapshot?,
      savedSessionId: identical(savedSessionId, _unset)
          ? this.savedSessionId
          : savedSessionId as int?,
      savedAt: identical(savedAt, _unset) ? this.savedAt : savedAt as DateTime?,
      discardedSnapshot: identical(discardedSnapshot, _unset)
          ? this.discardedSnapshot
          : discardedSnapshot as WorkoutSnapshot?,
      discardedAt: identical(discardedAt, _unset)
          ? this.discardedAt
          : discardedAt as DateTime?,
      plan: plan ?? this.plan,
      sets: sets ?? this.sets,
    );
  }

  static const _unset = Object();
}

class WorkoutCubit extends HydratedCubit<WorkoutState> {
  WorkoutCubit({this.repository, DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(WorkoutState.initial());

  final TrackerRepository? repository;

  final DateTime Function() _now;

  /// Begin a free-form workout (no split plan) at [startTime] now.
  ///
  /// Restore slots (last saved / last discarded) are carried over: starting a
  /// new session must not lose the ability to restore the previous one.
  void startWorkout({Gym? gym}) {
    emit(
      state.copyWith(
        isInProgress: true,
        startTime: DateTime.now(),
        gymId: gym?.id,
        gymName: gym?.name,
        planTitle: null,
        splitTitle: null,
        splitId: null,
        splitDayIndex: null,
        lastGymId: gym?.id ?? state.lastGymId,
        saveError: null,
        plan: const [],
        sets: const [],
      ),
    );
  }

  /// Begin a workout from a split day. [title] is the day's title and
  /// [splitTitle] its split's; [splitId] and [splitDayIndex] (the day's
  /// position) are written to the saved session for the Up next rotation.
  void startPlanWorkout({
    required String title,
    required List<PlanExercise> exercises,
    Gym? gym,
    String? splitTitle,
    int? splitId,
    int? splitDayIndex,
  }) {
    emit(
      state.copyWith(
        isInProgress: true,
        startTime: DateTime.now(),
        gymId: gym?.id,
        gymName: gym?.name,
        planTitle: title,
        splitTitle: splitTitle,
        splitId: splitId,
        splitDayIndex: splitDayIndex,
        lastGymId: gym?.id ?? state.lastGymId,
        saveError: null,
        plan: exercises,
        sets: const [],
      ),
    );
  }

  /// Move the running workout to [gym], which also becomes the gym the next
  /// workout starts at.
  void setGym(Gym gym) {
    emit(state.copyWith(gymId: gym.id, gymName: gym.name, lastGymId: gym.id));
  }

  /// Pick the gym the next workout starts at, without touching a running one.
  void rememberGym(Gym gym) {
    if (gym.id == state.lastGymId) return;
    emit(state.copyWith(lastGymId: gym.id));
  }

  /// Move an exercise card from [oldIndex] to [newIndex] (the index after
  /// removing it, as `ReorderableListView.onReorderItem` reports it).
  void reorderExercise(int oldIndex, int newIndex) {
    final plan = [...state.plan];
    if (oldIndex < 0 || oldIndex >= plan.length) return;
    final moved = plan.removeAt(oldIndex);
    plan.insert(newIndex.clamp(0, plan.length), moved);
    emit(
      state.copyWith(
        plan: [
          for (var i = 0; i < plan.length; i++)
            PlanExercise(
              exerciseId: plan[i].exerciseId,
              name: plan[i].name,
              order: i,
              sets: plan[i].sets,
            ),
        ],
      ),
    );
  }

  /// Add an exercise card to the session. Free workouts build their plan
  /// this way, one picked exercise at a time, so the cards survive restarts
  /// and restores. Returns false (and changes nothing) when the exercise is
  /// already in the session.
  bool addExercise({required int exerciseId, required String name}) {
    final present =
        state.plan.any((e) => e.exerciseId == exerciseId) ||
        state.sets.any((s) => s.exerciseId == exerciseId);
    if (present) return false;
    emit(
      state.copyWith(
        plan: [
          ...state.plan,
          PlanExercise(
            exerciseId: exerciseId,
            name: name,
            order: state.plan.length,
          ),
        ],
      ),
    );
    return true;
  }

  /// Remove an exercise card and every set logged for it.
  void removeExercise(int exerciseId) {
    final plan = [
      for (final e in state.plan)
        if (e.exerciseId != exerciseId) e,
    ];
    final sets = [
      for (final s in state.sets)
        if (s.exerciseId != exerciseId) s,
    ];
    emit(
      state.copyWith(
        plan: [
          for (var i = 0; i < plan.length; i++)
            PlanExercise(
              exerciseId: plan[i].exerciseId,
              name: plan[i].name,
              order: i,
              sets: plan[i].sets,
            ),
        ],
        sets: [
          for (var i = 0; i < sets.length; i++)
            ActiveSet(
              exerciseId: sets[i].exerciseId,
              exerciseName: sets[i].exerciseName,
              weight: sets[i].weight,
              reps: sets[i].reps,
              type: sets[i].type,
              order: i,
            ),
        ],
      ),
    );
  }

  void logSet({
    required int exerciseId,
    required String exerciseName,
    required double weight,
    required double reps,
    SetType type = SetType.working,
  }) {
    final sets = [
      ...state.sets,
      ActiveSet(
        exerciseId: exerciseId,
        exerciseName: exerciseName,
        weight: weight,
        reps: reps,
        type: type,
        order: state.sets.length,
      ),
    ];
    emit(state.copyWith(sets: sets));
  }

  void removeSet(int order) {
    var sets = state.sets.where((s) => s.order != order).toList();
    for (var i = 0; i < sets.length; i++) {
      sets[i] = ActiveSet(
        exerciseId: sets[i].exerciseId,
        exerciseName: sets[i].exerciseName,
        weight: sets[i].weight,
        reps: sets[i].reps,
        type: sets[i].type,
        order: i,
      );
    }
    emit(state.copyWith(sets: sets));
  }

  void updateSet(int order, {double? weight, double? reps, SetType? type}) {
    emit(
      state.copyWith(
        sets: [
          for (final set in state.sets)
            if (set.order == order)
              ActiveSet(
                exerciseId: set.exerciseId,
                exerciseName: set.exerciseName,
                weight: weight ?? set.weight,
                reps: reps ?? set.reps,
                type: type ?? set.type,
                order: set.order,
              )
            else
              set,
        ],
      ),
    );
  }

  Future<void> discardWorkout() async {
    final s = state;
    if (!s.isInProgress) return;
    final neverModified = s.sets.isEmpty;
    emit(
      s.copyWith(
        isInProgress: false,
        startTime: null,
        gymId: null,
        gymName: null,
        planTitle: null,
        splitTitle: null,
        splitId: null,
        splitDayIndex: null,
        saveError: null,
        plan: const [],
        sets: const [],
        discardedSnapshot: neverModified ? null : WorkoutSnapshot.fromState(s),
        discardedAt: neverModified ? null : _now(),
      ),
    );
  }

  Future<void> endWorkout() async {
    final s = state;
    if (!s.isInProgress) return;

    int? sessionId;
    final repo = repository;
    if (repo != null) {
      // Clear any previous save failure up-front so a repeated failure still
      // reaches listeners as a fresh state change (and re-shows the toast).
      if (s.saveError != null) emit(s.copyWith(saveError: null));

      final completed = WorkoutSession(
        title: s.planTitle == null
            ? (s.gymName != null ? '${s.gymName} workout' : 'Workout')
            : s.splitTitle == null
            ? s.planTitle!
            : '${s.splitTitle} · ${s.planTitle}',
        startTime: s.startTime ?? DateTime.now(),
        endTime: DateTime.now(),
        gymId: s.gymId,
        splitId: s.splitId,
        splitDayIndex: s.splitDayIndex,
        sets: s.sets
            .map(
              (a) => WorkoutSet(
                exerciseId: a.exerciseId,
                weight: a.weight,
                reps: a.reps,
                type: a.type,
                order: a.order,
              ),
            )
            .toList(),
      );

      // Error-surfacing contract for writes (PRODUCTION_READINESS.md Phase 1):
      // if the Isar write fails, the in-progress workout must NOT be discarded
      // from HydratedStorage. Surface the failure and keep the session alive
      // so the user can retry.
      try {
        sessionId = await repo.sessions.put(completed);
      } catch (error, stackTrace) {
        AppLog.error('workout', error, stackTrace);
        emit(
          s.copyWith(
            saveError:
                'Could not save the workout. Your session is still active.',
          ),
        );
        return;
      }

      // Keep per-exercise estimates fresh without changing the persisted
      // session shape. Existing manually entered multipliers remain fallback.
      // Best-effort only: the session is already persisted, so an estimation
      // failure must neither lose it nor block the end-workout flow.
      try {
        if (completed.gymId != null) {
          final primary = await repo.gyms.getPrimary();
          if (primary != null && primary.id != completed.gymId) {
            final gyms = await repo.gyms.getAll();
            final sessions = await repo.sessions.getAll();
            final estimates = estimateGymExerciseMultipliers(
              sessions,
              primary.id,
              completed.gymId!,
            );
            final gym = gyms.firstWhere(
              (candidate) => candidate.id == completed.gymId,
            );
            if (estimates.isNotEmpty) {
              gym.perExerciseMultipliers = [
                for (final entry in estimates.entries)
                  GymExerciseMultiplier(
                    exerciseId: entry.key,
                    multiplier: entry.value,
                  ),
              ];
              gym.multiplier =
                  estimateGymMultiplier(sessions, primary.id, gym.id) ??
                  gym.multiplier;
              await repo.gyms.put(gym);
            }
          }
        }
      } catch (error, stackTrace) {
        AppLog.error('workout-multiplier', error, stackTrace);
      }
    }

    emit(
      s.copyWith(
        isInProgress: false,
        startTime: null,
        gymId: null,
        gymName: null,
        planTitle: null,
        splitTitle: null,
        splitId: null,
        splitDayIndex: null,
        saveError: null,
        plan: const [],
        sets: const [],
        savedSnapshot: WorkoutSnapshot.fromState(s),
        savedSessionId: sessionId,
        savedAt: _now(),
      ),
    );
  }

  /// Restore the last saved workout as the in-progress session. The saved
  /// session is taken back out of history (it becomes ongoing again), so
  /// re-saving cannot duplicate it. If that delete fails, the restore is
  /// aborted rather than risking a duplicate history entry.
  Future<void> restoreSavedWorkout() async {
    final s = state;
    final snapshot = s.savedSnapshot;
    if (snapshot == null || s.isInProgress) return;

    final sessionId = s.savedSessionId;
    final repo = repository;
    if (sessionId != null && repo != null) {
      try {
        await repo.sessions.delete(sessionId);
      } catch (error, stackTrace) {
        AppLog.error('workout-restore', error, stackTrace);
        emit(
          s.copyWith(saveError: 'Could not restore the workout. Try again.'),
        );
        return;
      }
    }

    emit(
      s.copyWith(
        isInProgress: true,
        startTime: snapshot.startTime,
        gymId: snapshot.gymId,
        gymName: snapshot.gymName,
        planTitle: snapshot.planTitle,
        splitTitle: snapshot.splitTitle,
        splitId: snapshot.splitId,
        splitDayIndex: snapshot.splitDayIndex,
        saveError: null,
        plan: snapshot.plan,
        sets: snapshot.sets,
        savedSnapshot: null,
        savedSessionId: null,
        savedAt: null,
      ),
    );
  }

  void restoreDiscardedWorkout() {
    final s = state;
    final snapshot = s.discardedSnapshot;
    if (snapshot == null) return;

    if (!s.canRestoreDiscarded(now: _now())) {
      emit(s.copyWith(discardedSnapshot: null, discardedAt: null));
      return;
    }

    emit(
      s.copyWith(
        isInProgress: true,
        startTime: snapshot.startTime,
        gymId: snapshot.gymId,
        gymName: snapshot.gymName,
        planTitle: snapshot.planTitle,
        splitTitle: snapshot.splitTitle,
        splitId: snapshot.splitId,
        splitDayIndex: snapshot.splitDayIndex,
        saveError: null,
        plan: snapshot.plan,
        sets: snapshot.sets,
        discardedSnapshot: null,
        discardedAt: null,
      ),
    );
  }

  Future<void> restoreLastWorkout() async {
    final s = state;
    final now = _now();
    final savedRestorable =
        s.savedSnapshot != null &&
        (s.savedAt == null ||
            now.difference(s.savedAt!) < WorkoutState.discardRestoreWindow);
    final discardedRestorable = s.canRestoreDiscarded(now: now);
    if (savedRestorable && discardedRestorable) {
      final savedTime = s.savedAt;
      final discardedTime = s.discardedAt;
      if (savedTime != null &&
          discardedTime != null &&
          savedTime.isAfter(discardedTime)) {
        await restoreSavedWorkout();
      } else {
        restoreDiscardedWorkout();
      }
    } else if (savedRestorable) {
      await restoreSavedWorkout();
    } else if (discardedRestorable) {
      restoreDiscardedWorkout();
    }
  }

  @override
  WorkoutState fromJson(Map<String, dynamic> json) {
    return WorkoutState.fromJson(json);
  }

  @override
  Map<String, dynamic> toJson(WorkoutState state) {
    return state.toJson();
  }
}
