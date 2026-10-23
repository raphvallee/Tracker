import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/core/ui/max_width.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

import 'gym_picker.dart';
import 'new_split_page.dart';
import 'split_day_page.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  Stream<List<WorkoutSplit>>? _stream;
  Map<int, String> _exerciseNames = const {};
  bool _didLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoad) {
      _didLoad = true;
      final repo = RepositoryScope.maybeOf(context);
      _stream = repo?.splits.watchAll();
      repo?.exercises.getAll().then((exercises) {
        if (mounted) {
          setState(
            () => _exerciseNames = {
              for (final exercise in exercises) exercise.id: exercise.title,
            },
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsCubit = SettingsCubit.maybeOf(context);
    return CustomScrollView(
      slivers: <Widget>[
        CustomAppBar(context, title: 'Workout'),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: MaxWidth(
              child: settingsCubit == null
                  ? _buildSplits(context, FreeStartPlacement.before)
                  : BlocBuilder<SettingsCubit, SettingsState>(
                      bloc: settingsCubit,
                      builder: (context, settings) =>
                          _buildSplits(context, settings.freeStartPlacement),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSplits(
    BuildContext context,
    FreeStartPlacement freeStartPlacement,
  ) {
    return StreamBuilder<List<WorkoutSplit>>(
      stream: _stream,
      initialData: const <WorkoutSplit>[],
      builder: (context, snapshot) {
        final splits = snapshot.data ?? const <WorkoutSplit>[];
        final showStart = freeStartPlacement != FreeStartPlacement.disabled;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (showStart && freeStartPlacement == FreeStartPlacement.before)
              const BuildStartWorkoutButton(),
            if (showStart && freeStartPlacement == FreeStartPlacement.before)
              const SizedBox(height: 12),
            const BuildNewSplitButton(),
            const SizedBox(height: 12),
            if (splits.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No splits yet. Create one below.'),
              )
            else
              for (final split in splits)
                BuildMaterialSplit(split, exerciseNames: _exerciseNames),
            if (showStart &&
                freeStartPlacement == FreeStartPlacement.after) ...[
              const SizedBox(height: 12),
              const BuildStartWorkoutButton(),
            ],
          ],
        );
      },
    );
  }
}

class BuildStartWorkoutButton extends StatelessWidget {
  const BuildStartWorkoutButton({super.key});

  Future<void> _start(BuildContext context) async {
    final cubit = context.read<WorkoutCubit>();
    final repo = RepositoryScope.maybeOf(context);
    final gyms = (await repo?.gyms.getAll()) ?? const <Gym>[];
    if (!context.mounted) return;
    final gym = await promptGym(context, gyms);
    cubit.startWorkout(gym: gym);
  }

  @override
  Widget build(BuildContext context) {
    return FButton(
      onPress: () => _start(context),
      child: const Text('Start Workout', style: TextStyle(fontSize: 16)),
    );
  }
}

class BuildNewSplitButton extends StatelessWidget {
  const BuildNewSplitButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FButton(
      onPress: () => pushTo(context, const SplitEditorPage()),
      prefix: const Icon(FLucideIcons.plus, size: 16),
      child: const Text('New Split', overflow: TextOverflow.ellipsis),
    );
  }
}

class BuildMaterialSplit extends StatelessWidget {
  const BuildMaterialSplit(
    this.split, {
    required this.exerciseNames,
    super.key,
  });

  final WorkoutSplit split;
  final Map<int, String> exerciseNames;

  @override
  Widget build(BuildContext context) {
    return FCard(
      child: FItemGroup(
        divider: .full,
        children: <FItem>[
          FItem(
            key: ValueKey<String>('split-header-${split.id}'),
            title: Text(split.title, overflow: TextOverflow.ellipsis),
            suffix: const Icon(FLucideIcons.pen, size: 20),
            onPress: () => pushTo(context, SplitEditorPage(split: split)),
          ),
          for (var index = 0; index < split.splitDays.length; index++)
            FItem(
              key: ValueKey<String>('split-day-${split.id}-$index'),
              title: Text(
                split.splitDays[index].title,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                split.splitDays[index].exercises.isNotEmpty
                    ? split.splitDays[index].exercises
                          .map(
                            (e) =>
                                exerciseNames[e.exerciseId] ??
                                'Exercise ${e.exerciseId}',
                          )
                          .join(', ')
                    : 'No exercises yet',
                overflow: TextOverflow.ellipsis,
              ),
              onPress: () => pushTo(
                context,
                SplitDayPage(
                  splitTitle: split.title,
                  day: split.splitDays[index],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
