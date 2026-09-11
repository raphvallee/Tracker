import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/data/services/app_log.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/muscle.dart';
import 'package:tracker/routing/tab_navigation.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/core/ui/max_width.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/exercises/widgets/exercise_detail_page.dart';
import 'package:tracker/ui/exercises/widgets/new_exercise_page.dart';

Map<MuscleGroup, List<Exercise>> groupExercisesByMuscle(
  List<Exercise> exercises,
) {
  final grouped = <MuscleGroup, List<Exercise>>{};
  for (final exercise in exercises) {
    final muscleGroups = exercise.primaryMuscle
        .map((muscle) => Muscle.muscleToGroup[muscle]!)
        .toSet();
    for (final muscleGroup in muscleGroups) {
      grouped.putIfAbsent(muscleGroup, () => []).add(exercise);
    }
  }
  return grouped;
}

class ExercisesPage extends StatefulWidget {
  const ExercisesPage({super.key});

  @override
  State<ExercisesPage> createState() => _ExercisesPageState();
}

class _ExercisesPageState extends State<ExercisesPage> {
  List<Exercise> _exercises = const [];
  StreamSubscription<List<Exercise>>? _sub;
  bool _loaded = false;
  bool _isActive = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isActive = TabVisibilityScope.isActiveOf(context);
    if (!_loaded) {
      _loaded = true;
      _isActive = isActive;
      if (isActive) _subscribe();
    } else if (isActive != _isActive) {
      _isActive = isActive;
      if (isActive) {
        _subscribe();
      } else {
        _sub?.cancel();
        _sub = null;
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  void deactivate() {
    // Keep the explicit tab contract separate from Flutter deactivation: the
    // nested navigator remains mounted while its tab is inactive.
    super.deactivate();
  }

  void _subscribe() {
    if (_sub != null) return;
    final repo = RepositoryScope.maybeOf(context);
    if (repo == null) return;
    repo.exercises.getAll().then((list) {
      if (mounted && _isActive) setState(() => _exercises = list);
    });
    _sub = repo.exercises.watchAll().listen(
      (list) {
        if (mounted && _isActive) setState(() => _exercises = list);
      },
      onError: (Object error, StackTrace stack) {
        AppLog.error('exercises', error, stack);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: <Widget>[
        CustomAppBar(
          context,
          title: 'Exercises',
          actionButton: (
            title: 'New',
            onPressed: () => pushTo(context, const NewExercisePage()),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          sliver: SliverToBoxAdapter(
            child: MaxWidth(
              child: _exercises.isEmpty
                  ? const Text('No exercises in the library yet.')
                  : FTabs(
                      children: [
                        .entry(
                          label: const Text('Muscle group'),
                          child: _groupList(_groupsByMuscle(_exercises)),
                        ),
                        .entry(
                          label: const Text('Movement'),
                          child: _groupList(_groupsByMovement(_exercises)),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _groupList(List<_ExerciseGroup> groups) {
    return Column(
      children: [
        for (final group in groups)
          _GroupSection(
            key: ValueKey<String>('exercise-group-${group.id}'),
            title: group.title,
            exercises: group.exercises,
          ),
      ],
    );
  }

  List<_ExerciseGroup> _groupsByMuscle(List<Exercise> exercises) {
    final grouped = groupExercisesByMuscle(exercises);
    return [
      for (final entry in grouped.entries)
        _ExerciseGroup(
          id: 'muscle-${entry.key.name}',
          title: MuscleGroupLabel.label(entry.key),
          exercises: entry.value,
        ),
    ];
  }

  List<_ExerciseGroup> _groupsByMovement(List<Exercise> exercises) {
    final grouped = <MovementPattern, List<Exercise>>{};
    for (final exercise in exercises) {
      grouped.putIfAbsent(exercise.movementPattern, () => []).add(exercise);
    }
    return [
      for (final entry in grouped.entries)
        _ExerciseGroup(
          id: 'movement-${entry.key.name}',
          title: MovementPatternLabel.label(entry.key),
          exercises: entry.value,
        ),
    ];
  }
}

class _ExerciseGroup {
  const _ExerciseGroup({
    required this.id,
    required this.title,
    required this.exercises,
  });

  final String id;
  final String title;
  final List<Exercise> exercises;
}

class _GroupSection extends StatelessWidget {
  const _GroupSection({
    super.key,
    required this.title,
    required this.exercises,
  });

  final String title;
  final List<Exercise> exercises;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FAccordion(
        children: [
          FAccordionItem(
            title: Text('$title (${exercises.length})'),
            child: FItemGroup(
              divider: .full,
              children: [
                for (final exercise in exercises)
                  FItem(
                    key: ValueKey<String>('exercise-${exercise.id}'),
                    title: Text(exercise.title),
                    subtitle: Text(
                      exercise.equipment.map((eq) => eq.displayName).join(', '),
                      overflow: TextOverflow.ellipsis,
                    ),
                    suffix: const Icon(FLucideIcons.chevronRight),
                    onPress: () =>
                        pushTo(context, ExerciseDetailPage(exercise: exercise)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MuscleGroupLabel {
  static String label(MuscleGroup g) => switch (g) {
    MuscleGroup.abdominals => 'Abdominals',
    MuscleGroup.arms => 'Arms',
    MuscleGroup.shoulders => 'Shoulders',
    MuscleGroup.back => 'Back',
    MuscleGroup.legs => 'Legs',
    MuscleGroup.chest => 'Chest',
  };
}

class MovementPatternLabel {
  static String label(MovementPattern pattern) => switch (pattern) {
    MovementPattern.unspecified => 'Other',
    MovementPattern.push => 'Push',
    MovementPattern.pull => 'Pull',
    MovementPattern.legs => 'Legs',
    MovementPattern.core => 'Core',
    MovementPattern.fullBody => 'Full body',
  };
}
