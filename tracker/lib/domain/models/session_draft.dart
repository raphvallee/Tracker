import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';

/// One set of a [SessionDraft]: the values it saves with, and the saved set
/// it was opened from.
class SetDraft {
  const SetDraft({
    required this.exerciseId,
    required this.weight,
    required this.reps,
    this.warmup = false,
    this.rpe,
    this.order = 0,
    this.origin,
  });

  factory SetDraft.of(WorkoutSet set, int origin) => SetDraft(
    exerciseId: set.exerciseId,
    weight: set.weight,
    reps: set.reps,
    warmup: set.isWarmup,
    rpe: set.rpe,
    order: set.order,
    origin: origin,
  );

  final int exerciseId;

  /// Kilograms, as stored.
  final double weight;
  final double reps;

  /// Not one of the exercise's working sets.
  final bool warmup;

  /// How hard the set was, as RPE; null when not rated.
  final double? rpe;
  final int order;

  /// Position of the saved set this one was opened from; null for a set
  /// added in the draft.
  final int? origin;

  bool get isNew => origin == null;

  SetDraft copyWith({
    double? weight,
    double? reps,
    bool? warmup,
    Object? rpe = _unset,
  }) => SetDraft(
    exerciseId: exerciseId,
    weight: weight ?? this.weight,
    reps: reps ?? this.reps,
    warmup: warmup ?? this.warmup,
    rpe: identical(rpe, _unset) ? this.rpe : (rpe as num?)?.toDouble(),
    order: order,
    origin: origin,
  );

  static const _unset = Object();

  WorkoutSet toSet() => WorkoutSet(
    exerciseId: exerciseId,
    weight: weight,
    reps: reps,
    type: warmup ? SetType.warmup : SetType.working,
    order: order,
    rpe: rpe,
  );

  /// Whether it would save anything other than [saved].
  bool differsFrom(WorkoutSet saved) =>
      exerciseId != saved.exerciseId ||
      !sameKilograms(weight, saved.weight) ||
      reps != saved.reps ||
      warmup != saved.isWarmup ||
      rpe != saved.rpe;
}

/// Two stored weights are the same set weight.
bool sameKilograms(double a, double b) => (a - b).abs() < 1e-9;

/// An editable copy of a past workout. Nothing reaches the saved workout
/// until [applyTo] writes the draft over it.
class SessionDraft {
  const SessionDraft({
    required this.title,
    required this.startTime,
    this.endTime,
    this.gymId,
    this.sets = const [],
  });

  factory SessionDraft.of(WorkoutSession session) => SessionDraft(
    title: session.title,
    startTime: session.startTime,
    endTime: session.endTime,
    gymId: session.gymId,
    sets: [for (final (i, set) in session.sets.indexed) SetDraft.of(set, i)],
  );

  final String title;
  final DateTime startTime;
  final DateTime? endTime;
  final int? gymId;

  /// In logged order.
  final List<SetDraft> sets;

  SessionDraft copyWith({
    String? title,
    DateTime? startTime,
    Object? endTime = _unset,
    Object? gymId = _unset,
    List<SetDraft>? sets,
  }) => SessionDraft(
    title: title ?? this.title,
    startTime: startTime ?? this.startTime,
    endTime: identical(endTime, _unset) ? this.endTime : endTime as DateTime?,
    gymId: identical(gymId, _unset) ? this.gymId : gymId as int?,
    sets: sets ?? this.sets,
  );

  static const _unset = Object();

  SessionDraft updateSet(int index, SetDraft Function(SetDraft set) change) =>
      copyWith(
        sets: [
          for (final (i, set) in sets.indexed) i == index ? change(set) : set,
        ],
      );

  SessionDraft removeSet(int index) =>
      copyWith(sets: [...sets]..removeAt(index));

  /// Adds a working set to [exerciseId], right after its last one and with
  /// that set's weight and reps; an exercise with no sets yet gets [weight]
  /// and [reps], at the end.
  SessionDraft addSet(int exerciseId, {double weight = 0, double reps = 1}) {
    final last = sets.lastIndexWhere((set) => set.exerciseId == exerciseId);
    final added = SetDraft(
      exerciseId: exerciseId,
      weight: last < 0 ? weight : sets[last].weight,
      reps: last < 0 ? reps : sets[last].reps,
      order: _nextOrder,
    );
    return copyWith(sets: [...sets]..insert(addedSetIndex(exerciseId), added));
  }

  /// Index of the set [addSet] would add for [exerciseId].
  int addedSetIndex(int exerciseId) {
    final last = sets.lastIndexWhere((set) => set.exerciseId == exerciseId);
    return last < 0 ? sets.length : last + 1;
  }

  int get _nextOrder {
    var next = 0;
    for (final set in sets) {
      if (set.order >= next) next = set.order + 1;
    }
    return next;
  }

  /// [saved] with the draft's values. Everything the draft does not edit
  /// (its id, the split day it was started from) is kept.
  WorkoutSession applyTo(WorkoutSession saved) => WorkoutSession(
    title: title.trim(),
    startTime: startTime,
    endTime: endTime,
    gymId: gymId,
    splitId: saved.splitId,
    splitDayIndex: saved.splitDayIndex,
    sets: [for (final set in sets) set.toSet()],
  )..id = saved.id;
}
