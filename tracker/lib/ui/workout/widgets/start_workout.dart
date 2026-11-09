import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/rep_mode.dart';
import 'package:tracker/domain/models/split_draft.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/routing/tab_navigation.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

/// The rep target new planned sets start with: the Settings defaults.
SetTarget defaultSetTarget(SettingsState settings) =>
    settings.defaultRepMode == RepMode.fixed
    ? SetTarget(settings.defaultReps)
    : SetTarget(settings.defaultRepRangeMin, settings.defaultRepRangeMax);

SetTarget defaultSetTargetOf(BuildContext context) =>
    defaultSetTarget(SettingsCubit.maybeOf(context)?.state ?? SettingsState());

/// The gym a new workout starts at: the last one used, else the primary gym,
/// else the first; null when no gym is saved.
Gym? startGymOf(List<Gym> gyms, int? lastGymId) {
  if (gyms.isEmpty) return null;
  for (final gym in gyms) {
    if (gym.id == lastGymId) return gym;
  }
  for (final gym in gyms) {
    if (gym.isPrimary) return gym;
  }
  return gyms.first;
}

/// The exercises (with their planned sets) a workout of [split]'s day at
/// [dayIndex] follows. [names] titles exercises by id.
List<PlanExercise> planOf(
  WorkoutSplit split,
  int dayIndex,
  Map<int, String> names, {
  SetTarget fallback = const SetTarget(8, 12),
}) {
  final day = SplitDraft.fromSplit(split, fallback: fallback).days[dayIndex];
  return [
    for (final (i, exercise) in day.exercises.indexed)
      PlanExercise(
        exerciseId: exercise.exerciseId,
        name: names[exercise.exerciseId] ?? 'Exercise ${exercise.exerciseId}',
        order: i,
        sets: [for (final (k, set) in exercise.sets.indexed) set.toPlanned(k)],
      ),
  ];
}

/// Starts [split]'s day at [dayIndex] at once, at the remembered gym, and
/// shows the Workout tab.
Future<void> startSplitDay(
  BuildContext context, {
  required WorkoutSplit split,
  required int dayIndex,
  required Map<int, String> names,
}) async {
  final cubit = context.read<WorkoutCubit>();
  if (dayIndex < 0 || dayIndex >= split.splitDays.length) return;
  final fallback = defaultSetTargetOf(context);
  final gyms = await RepositoryScope.maybeOf(context)?.gyms.getAll() ?? [];
  // Never clobber an active session: it would drop every logged set.
  if (!context.mounted || cubit.state.isInProgress) return;
  cubit.startPlanWorkout(
    title: split.splitDays[dayIndex].title,
    splitTitle: split.title,
    splitId: split.id,
    splitDayIndex: dayIndex,
    gym: startGymOf(gyms, cubit.state.lastGymId),
    exercises: planOf(split, dayIndex, names, fallback: fallback),
  );
  HomePageSingleton().changeTab(TabName.currentWorkout);
}

/// Starts a workout with no plan at the remembered gym.
Future<void> startEmptyWorkout(BuildContext context) async {
  final cubit = context.read<WorkoutCubit>();
  final gyms = await RepositoryScope.maybeOf(context)?.gyms.getAll() ?? [];
  if (!context.mounted || cubit.state.isInProgress) return;
  cubit.startWorkout(gym: startGymOf(gyms, cubit.state.lastGymId));
  HomePageSingleton().changeTab(TabName.currentWorkout);
}
