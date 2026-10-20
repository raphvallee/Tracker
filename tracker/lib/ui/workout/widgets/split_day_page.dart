import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/routing/tab_navigation.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

import 'gym_picker.dart';

/// A real detail screen for one split day (Milestone 3): shows the day's
/// exercises and lets the user start that workout as the active session. This
/// replaces the old `Text('restart if stuck in fake workout')` placeholder.
class SplitDayPage extends StatefulWidget {
  const SplitDayPage({super.key, required this.splitTitle, required this.day});

  final String splitTitle;
  final WorkoutSplitDay day;

  @override
  State<SplitDayPage> createState() => _SplitDayPageState();
}

class _SplitDayPageState extends State<SplitDayPage> {
  Map<int, String> _names = const {};
  bool _loading = true;
  bool _didLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // RepositoryScope is an inherited widget, so read it here (after initState)
    // rather than in initState.
    if (!_didLoad) {
      _didLoad = true;
      _load();
    }
  }

  Future<void> _load() async {
    final repo = RepositoryScope.maybeOf(context);
    final exercises = await repo?.exercises.getAll() ?? const [];
    final names = <int, String>{for (final e in exercises) e.id: e.title};
    if (!mounted) return;
    setState(() {
      _names = names;
      _loading = false;
    });
  }

  Future<void> _startWorkout(BuildContext context) async {
    final cubit = context.read<WorkoutCubit>();
    // Never clobber an active session (it would drop every logged set); the
    // start button is hidden while one is in progress, this is the belt to
    // that suspenders.
    if (cubit.state.isInProgress) return;
    final repo = RepositoryScope.maybeOf(context);
    final gyms = (await repo?.gyms.getAll()) ?? const <Gym>[];
    if (!context.mounted) return;
    final gym = await promptGym(context, gyms);

    final plan = <PlanExercise>[];
    final items = widget.day.exercises;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      plan.add(
        PlanExercise(
          exerciseId: item.exerciseId,
          name: _names[item.exerciseId] ?? 'Exercise ${item.exerciseId}',
          order: i,
          sets: item.sets,
        ),
      );
    }
    cubit.startPlanWorkout(
      title: '${widget.splitTitle} · ${widget.day.title}',
      exercises: plan,
      gym: gym,
    );
    HomePageSingleton().changeTab(TabName.currentWorkout);
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: <Widget>[
        CustomAppBar(context, title: widget.day.title),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  '${widget.splitTitle} · ${widget.day.title}',
                  style: context.theme.typography.body.xl.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.day.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.day.description,
                    style: context.theme.typography.body.sm,
                  ),
                ],
                const SizedBox(height: 16),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (items.isEmpty)
                  const Text('No exercises in this day yet.')
                else
                  for (final (index, item) in items.indexed)
                    FCard(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Text('${index + 1}'),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _names[item.exerciseId] ??
                                        'Exercise ${item.exerciseId}',
                                  ),
                                  ...[_targetSubtitle(item)]
                                      .whereType<Widget>(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                const SizedBox(height: 4),
                const SizedBox(height: 24),
                // Reactive on the cubit so the button comes back the moment
                // the active session ends (no dialog, no discard choice - the
                // running session's logged sets must never be at risk).
                BlocSelector<WorkoutCubit, WorkoutState, bool>(
                  selector: (state) => state.isInProgress,
                  builder: (context, isInProgress) => isInProgress
                      ? const _ActiveSessionNotice()
                      : FButton(
                          onPress: () => _startWorkout(context),
                          prefix: const Icon(FLucideIcons.play),
                          child: const Text('Start this workout'),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<ExerciseItem> get items => widget.day.exercises;

  Widget? _targetSubtitle(ExerciseItem item) {
    // Planned sets are the source of truth; legacy items (saved before sets
    // existed) fall back to their old target fields.
    final summary = plannedSetsSummary(item.sets);
    if (summary != null) return Text(summary);
    if (item.targetSets == null && item.targetReps == null) return null;
    final parts = <String>[];
    if (item.targetSets != null) parts.add('${item.targetSets} sets');
    if (item.targetReps != null) parts.add('${item.targetReps} reps');
    return Text(parts.join(' × '));
  }
}

/// Shown instead of the start button while a workout session is already in
/// progress: explains why starting is blocked and offers a shortcut to the
/// running session. No discard path - zero data-loss routes by design.
class _ActiveSessionNotice extends StatelessWidget {
  const _ActiveSessionNotice();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Finish your current workout first',
          textAlign: TextAlign.center,
          style: context.theme.typography.body.sm,
        ),
        const SizedBox(height: 12),
        FButton(
          onPress: () => HomePageSingleton().changeTab(TabName.currentWorkout),
          prefix: const Icon(FLucideIcons.squareArrowRight),
          child: const Text('Go to current workout'),
        ),
      ],
    );
  }
}
