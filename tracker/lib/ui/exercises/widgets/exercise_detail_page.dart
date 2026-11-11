import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/graph_config.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/services/analytics.dart';
import 'package:tracker/domain/services/graph_series.dart';
import 'package:tracker/ui/analytics/widgets/graph_panel.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/core/ui/max_width.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/ui/exercises/widgets/new_exercise_page.dart';

class ExerciseDetailPage extends StatefulWidget {
  const ExerciseDetailPage({super.key, required this.exercise});

  final Exercise exercise;

  @override
  State<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends State<ExerciseDetailPage> {
  Map<int, double> _multipliers = const {};
  bool _didLoad = false;
  final AnalyticsService _analytics = AnalyticsService();
  late Exercise _exercise = widget.exercise;
  AnalyticsSnapshot _snapshot = AnalyticsSnapshot(
    best1rm: const [],
    peakWeight: const [],
    volume: const [],
    summary: const ExerciseSummary(best1rm: 0, peakVolume: 0, sessionCount: 0),
    exerciseId: null,
    revision: null,
  );
  GraphSeries? _best1rm;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoad) {
      _didLoad = true;
      _load();
    }
  }

  Future<void> _load() async {
    final repo = RepositoryScope.maybeOf(context);
    final sessions = await repo?.sessions.getAll() ?? const <WorkoutSession>[];
    final gyms = await repo?.gyms.getAll() ?? const [];
    if (!mounted) return;
    setState(() {
      _multipliers = {for (final g in gyms) g.id: g.multiplier};
      final exerciseMultipliers = <int, Map<int, double>>{
        for (final gym in gyms)
          gym.id: {
            for (final value in gym.perExerciseMultipliers)
              value.exerciseId: value.multiplier,
          },
      };
      _snapshot = _analytics.snapshot(
        sessions: sessions,
        multipliers: _multipliers,
        exerciseMultipliers: exerciseMultipliers,
        exerciseId: widget.exercise.id,
        revision: sessions.length,
      );
      _best1rm = graphSeries(
        sessions: sessions,
        exerciseId: widget.exercise.id,
        metric: GraphMetric.best1rm,
        range: GraphTimeframe.all,
        now: DateTime.now(),
        multipliers: _multipliers,
        exerciseMultipliers: exerciseMultipliers,
      );
    });
  }

  /// Opens the editor for this exercise. The editor pops the saved exercise,
  /// or nothing when it deleted the exercise (verified against the repository,
  /// since cancelling also pops without a result).
  Future<void> _edit() async {
    final updated = await pushTo<Exercise>(
      context,
      NewExercisePage(exercise: _exercise),
    );
    if (!mounted) return;
    final repo = RepositoryScope.maybeOf(context);
    final fresh = await repo?.exercises.getById(_exercise.id);
    if (!mounted) return;
    if (fresh == null) {
      Navigator.of(context).pop();
    } else if (updated != null) {
      setState(() => _exercise = fresh);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final exercise = _exercise;
    final best1rm = _best1rm;
    final summary = _snapshot.summary;

    return CustomScrollView(
      slivers: <Widget>[
        CustomAppBar(
          context,
          title: exercise.title,
          actionButton: (title: 'Edit', onPressed: _edit),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: MaxWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (exercise.description != null) ...[
                    Text(
                      exercise.description!,
                      style: theme.typography.body.lg,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _InfoRow(
                    label: 'Movement pattern',
                    value: MovementPatternLabel.label(exercise.movementPattern),
                  ),
                  _InfoRow(
                    label: 'Primary muscles',
                    value: exercise.primaryMuscle
                        .map((m) => m.scientificName)
                        .join(', '),
                  ),
                  if (exercise.secondaryMuscle != null &&
                      exercise.secondaryMuscle!.isNotEmpty)
                    _InfoRow(
                      label: 'Secondary muscles',
                      value: exercise.secondaryMuscle!
                          .map((m) => m.scientificName)
                          .join(', '),
                    ),
                  _InfoRow(
                    label: 'Equipment',
                    value: exercise.equipment
                        .map((e) => e.displayName)
                        .join(', '),
                  ),
                  const SizedBox(height: 16),
                  const FDivider(),
                  const SizedBox(height: 16),
                  Text(
                    'Performance history',
                    style: theme.typography.body.md.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _Stat(
                          label: 'Best 1RM',
                          value: formatWeight(context, summary.best1rm),
                        ),
                        const SizedBox(width: 8),
                        _Stat(
                          label: 'Peak volume',
                          value: formatWeight(context, summary.peakVolume),
                        ),
                        const SizedBox(width: 8),
                        _Stat(
                          label: 'Sessions',
                          value: '${summary.sessionCount}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Best working-set 1RM over time',
                    style: theme.typography.body.sm,
                  ),
                  const SizedBox(height: 8),
                  if (best1rm != null) GraphPanel(series: best1rm),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Expanded(
      child: FCard(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: <Widget>[
              Text(
                value,
                style: theme.typography.body.md.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.typography.body.xs.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 175,
            child: Text(
              label,
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.typography.body.sm)),
        ],
      ),
    );
  }
}

class MovementPatternLabel {
  static String label(MovementPattern m) => switch (m) {
    MovementPattern.unspecified => 'Unspecified',
    MovementPattern.push => 'Push',
    MovementPattern.pull => 'Pull',
    MovementPattern.legs => 'Legs',
    MovementPattern.core => 'Core',
    MovementPattern.fullBody => 'Full body',
  };
}
