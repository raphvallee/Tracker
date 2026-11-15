import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/domain/services/gym_equivalence.dart';
import 'package:tracker/domain/services/set_prefill.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

/// What an exercise brings to a workout at one gym: last time's sets as
/// they read there, how they were converted, and how its machine is set up.
class ExerciseAtGym {
  const ExerciseAtGym({
    this.exercise,
    this.gym,
    this.home,
    this.logged,
    this.previous,
    this.conversion,
    this.effectiveReps = false,
  });

  final Exercise? exercise;

  /// The workout's gym; null without one.
  final Gym? gym;

  /// The primary gym, the one every factor is measured against.
  final Gym? home;

  /// Last time's sets as logged, at the gym they were done at.
  final PreviousPerformance? logged;

  /// Last time's sets as they read at [gym]: [logged] converted, else
  /// [logged] itself.
  final PreviousPerformance? previous;

  /// How [logged] was converted; null when it was not.
  final GymConversion? conversion;

  /// Whether rated sets count their reps in reserve (the setting): a set
  /// rated very easy or very hard then moves the pending rows too.
  final bool effectiveReps;

  /// A machine or a cable: its weights differ from gym to gym.
  bool get isMachine {
    final exercise = this.exercise;
    return exercise != null && convertsAcrossGyms(exercise.equipment);
  }

  /// How the machine is set up at [gym]; null without a note.
  String? get setupNote {
    final gym = this.gym;
    final exercise = this.exercise;
    return gym == null || exercise == null
        ? null
        : setupNoteOf(gym, exercise.id);
  }
}

/// [kilograms] at the gym [conversion] comes from as kilograms at its gym,
/// rounded to a load the machine makes. Unchanged when the factors match.
double convertedLoad(
  GymConversion conversion,
  double kilograms,
  WeightUnit unit,
) {
  final converted = conversion.convert(kilograms);
  return converted == kilograms ? kilograms : roundToLoad(converted, unit);
}

/// The placeholder for pending row [index] once some sets are [logged]:
/// when last time's weights were converted for this gym, they follow how
/// far the logged ones landed from them ([loggedCorrection]), so a first
/// set heavier than the guess, or with effective reps one rated very easy,
/// brings the rest along.
SetGhost correctedGhost(
  SetGhost ghost, {
  required int index,
  required List<ActiveSet> logged,
  required ExerciseAtGym? atGym,
  required WeightUnit unit,
}) {
  final weight = ghost.weight;
  final last = atGym?.previous?.sets;
  if (atGym?.conversion == null ||
      weight == null ||
      last == null ||
      ghost.warmup ||
      index < logged.length ||
      index >= last.length ||
      last[index].isWarmup) {
    return ghost;
  }
  final ratio = loggedCorrection(
    [
      for (final set in logged)
        (
          weight: set.weight,
          reps: set.reps,
          rpe: set.rpe,
          warmup: set.isWarmup,
        ),
    ],
    last,
    effectiveReps: atGym?.effectiveReps ?? false,
  );
  if (ratio == 1) return ghost;
  return SetGhost(
    weight: roundToLoad(weight * ratio, unit),
    reps: ghost.reps,
    warmup: ghost.warmup,
  );
}

/// Builds with what [exerciseId] brings to a workout at [gymId], kept up
/// to date as the gyms change: null until it has loaded.
class WithExerciseAtGym extends StatefulWidget {
  const WithExerciseAtGym({
    super.key,
    required this.exerciseId,
    required this.gymId,
    required this.builder,
  });

  final int exerciseId;
  final int? gymId;
  final Widget Function(BuildContext context, ExerciseAtGym? atGym) builder;

  @override
  State<WithExerciseAtGym> createState() => _WithExerciseAtGymState();
}

class _WithExerciseAtGymState extends State<WithExerciseAtGym> {
  StreamSubscription<List<Gym>>? _subscription;
  List<Gym>? _gyms;
  PreviousPerformance? _logged;
  Exercise? _exercise;
  int? _loadedFor;
  bool _loaded = false;
  bool _noRepository = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(covariant WithExerciseAtGym oldWidget) {
    super.didUpdateWidget(oldWidget);
    _load();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _load() {
    if (_loadedFor == widget.exerciseId) return;
    _loadedFor = widget.exerciseId;
    final repo = RepositoryScope.maybeOf(context);
    if (repo == null) {
      _noRepository = true;
      return;
    }
    _subscription ??= repo.gyms.watchAll().listen((gyms) {
      if (mounted) setState(() => _gyms = gyms);
    });
    final id = widget.exerciseId;
    _loaded = false;
    (
      repo.sessions.getPreviousPerformance(id),
      repo.exercises.getById(id),
    ).wait.then((loaded) {
      if (!mounted || _loadedFor != id) return;
      final (logged, exercise) = loaded;
      setState(() {
        _logged = logged;
        _exercise = exercise;
        _loaded = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_noRepository) return widget.builder(context, const ExerciseAtGym());
    final gyms = _gyms;
    if (!_loaded || gyms == null) return widget.builder(context, null);
    Gym? gym;
    Gym? home;
    for (final candidate in gyms) {
      if (candidate.id == widget.gymId) gym = candidate;
      if (candidate.isPrimary) home = candidate;
    }
    final exercise = _exercise;
    final logged = _logged;
    final conversion = gymConversionOf(
      converts: exercise != null && convertsAcrossGyms(exercise.equipment),
      gyms: gyms,
      exerciseId: widget.exerciseId,
      fromGymId: logged?.gymId,
      toGymId: widget.gymId,
    );
    final unit = weightUnitOf(context);
    return widget.builder(
      context,
      ExerciseAtGym(
        exercise: exercise,
        gym: gym,
        home: home,
        logged: logged,
        previous: logged == null || conversion == null
            ? logged
            : logged.withWeights(
                (kilograms) => convertedLoad(conversion, kilograms, unit),
              ),
        conversion: conversion,
        effectiveReps: countsEffectiveReps(context),
      ),
    );
  }
}
