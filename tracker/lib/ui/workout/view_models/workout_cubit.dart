import 'dart:collection';

import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/data/services/app_log.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/domain/services/analytics.dart';

/// A single set logged during the in-progress workout.
///
/// Lives in the cubit-local [WorkoutState] (serialized for hydration so an
/// active workout survives an app restart). It mirrors the persisted
/// [WorkoutSet] but snapshots [exerciseName] so the UI can render set rows
/// without a DB read. [order] preserves sequence.
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
    reps: _intValue(json['reps']),
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
  final int reps;
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

/// An exercise the user intends to do this session ("the split's exercises for
/// today"). Captured at start so the active-workout screen can lay out the plan
/// even after the underlying [WorkoutSplit] changes. Carries the planned sets
/// so the session can pre-fill the add-set form from the plan.
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

final _setsByExerciseCache = Expando<Map<int, List<ActiveSet>>>();
final _workingVolumeCache = Expando<double>();

class WorkoutState {
  WorkoutState({
    required this.isInProgress,
    this.startTime,
    this.gymId,
    this.gymName,
    this.planTitle,
    this.saveError,
    List<PlanExercise> plan = const [],
    List<ActiveSet> sets = const [],
  }) : _plan = List.unmodifiable(plan),
       _sets = List.unmodifiable(sets);

  factory WorkoutState.fromJson(Map<String, dynamic> json) {
    // Hydrated-state schema versioning (PRODUCTION_READINESS.md Phase 1).
    // v1 = the original shape; payloads written before versioning have no
    // 'v' key and read as v1. Unknown future versions fall back to a clean
    // idle state instead of crashing.
    switch (json['v'] as int? ?? 1) {
      case 1:
        return _fromV1(json);
      default:
        return WorkoutState.initial();
    }
  }

  static WorkoutState _fromV1(Map<String, dynamic> json) {
    final rawPlan = json['plan'];
    final rawSets = json['sets'];
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
      plan: rawPlan is List
          ? rawPlan
                .whereType<Map>()
                .map((entry) {
                  try {
                    return PlanExercise.fromJson(
                      Map<String, dynamic>.from(entry),
                    );
                  } catch (_) {
                    return null;
                  }
                })
                .whereType<PlanExercise>()
                .toList(growable: false)
          : const [],
      sets: rawSets is List
          ? rawSets
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
          : const [],
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

  /// Foreign key + display snapshot of the gym this session is logged at
  /// (see Plan.md §2.2). Null if no gym was selected.
  final int? gymId;
  final String? gymName;

  /// Title + ordered exercise plan if this session follows a split day.
  final String? planTitle;

  /// Set when the final Isar write in [WorkoutCubit.endWorkout] failed. Purely
  /// transient UI feedback - deliberately excluded from hydration JSON, so a
  /// restarted app never boots into a stale error banner.
  final String? saveError;

  /// Sets logged so far this session, in [ActiveSet.order] sequence.

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
      saveError == other.saveError &&
      _listEquals(plan, other.plan) &&
      _listEquals(sets, other.sets);

  @override
  int get hashCode => Object.hash(
    isInProgress,
    startTime,
    gymId,
    gymName,
    planTitle,
    saveError,
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

  /// Working-set volume for the live workout summary (warm-ups excluded).
  double get workingVolume => _workingVolumeCache[this] ??= sets
      .where((set) => !set.isWarmup)
      .fold<double>(0, (total, set) => total + set.weight * set.reps);

  /// The resting (no workout) state - the app does not boot into a session.
  static WorkoutState initial() => WorkoutState(isInProgress: false);

  Map<String, dynamic> toJson() => {
    // Hydrated-state schema version; see the comment on fromJson.
    'v': 1,
    'isInProgress': isInProgress,
    'startTime': startTime?.toIso8601String(),
    'gymId': gymId,
    'gymName': gymName,
    'planTitle': planTitle,
    'plan': plan.map((e) => e.toJson()).toList(),
    'sets': sets.map((s) => s.toJson()).toList(),
  };

  WorkoutState copyWith({
    bool? isInProgress,
    Object? startTime = _unset,
    Object? gymId = _unset,
    Object? gymName = _unset,
    Object? planTitle = _unset,
    Object? saveError = _unset,
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
      saveError: identical(saveError, _unset)
          ? this.saveError
          : saveError as String?,
      plan: plan ?? this.plan,
      sets: sets ?? this.sets,
    );
  }

  static const _unset = Object();
}

class WorkoutCubit extends HydratedCubit<WorkoutState> {
  WorkoutCubit({this.repository}) : super(WorkoutState.initial());

  /// Reference for the workout flow; `endWorkout` persists a real
  /// [WorkoutSession] (with sets + gym + duration) to Isar instead of doing its
  /// own DB work. The cubit never opens a connection itself.
  final TrackerRepository? repository;

  /// Begin a free-form workout (no split plan) at [startTime] now.
  void startWorkout({Gym? gym}) {
    emit(
      WorkoutState(
        isInProgress: true,
        startTime: DateTime.now(),
        gymId: gym?.id,
        gymName: gym?.name,
      ),
    );
  }

  /// Begin a workout following a split day's exercise plan.
  void startPlanWorkout({
    required String title,
    required List<PlanExercise> exercises,
    Gym? gym,
  }) {
    emit(
      WorkoutState(
        isInProgress: true,
        startTime: DateTime.now(),
        gymId: gym?.id,
        gymName: gym?.name,
        planTitle: title,
        plan: exercises,
      ),
    );
  }

  /// Select/change the gym for the active (or upcoming) session.
  void setGym(Gym gym) {
    emit(state.copyWith(gymId: gym.id, gymName: gym.name));
  }

  /// Log one performed set, appending it in sequence.
  void logSet({
    required int exerciseId,
    required String exerciseName,
    required double weight,
    required int reps,
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

  /// Remove the set at [order] and reindex the rest so [ActiveSet.order] stays
  /// contiguous.
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

  /// Abandon the workout without persisting anything. Nothing was saved to
  /// Isar yet, so clearing the hydrated state is all that is needed.
  Future<void> discardWorkout() async {
    if (!state.isInProgress) return;
    emit(WorkoutState.initial());
  }

  /// Finish the workout: writes a [WorkoutSession] to Isar (duration = now -
  /// start) and resets to the idle state. When no repository is wired (tests),
  /// it only resets state.
  Future<void> endWorkout() async {
    final s = state;
    if (!s.isInProgress) return;

    final repo = repository;
    if (repo != null) {
      // Clear any previous save failure up-front so a repeated failure still
      // reaches listeners as a fresh state change (and re-shows the toast).
      if (s.saveError != null) emit(s.copyWith(saveError: null));

      final completed = WorkoutSession(
        title:
            s.planTitle ??
            (s.gymName != null ? '${s.gymName} workout' : 'Workout'),
        startTime: s.startTime ?? DateTime.now(),
        endTime: DateTime.now(),
        gymId: s.gymId,
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
        await repo.sessions.put(completed);
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

    emit(WorkoutState.initial());
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
