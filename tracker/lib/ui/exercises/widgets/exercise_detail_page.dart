import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/services/analytics.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/core/ui/line_chart.dart';
import 'package:tracker/ui/core/ui/max_width.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/ui/exercises/widgets/new_exercise_page.dart';

/// Individual exercise view (Plan.md §1.4.1.1): profile rows plus a
/// performance-history section (Milestone 6) charting the best normalized
/// working-set 1RM per session over time, with warm-ups excluded (§2.1).
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
  // Local copy so an edit from the editor page refreshes this view.
  late Exercise _exercise = widget.exercise;
  AnalyticsSnapshot _snapshot = AnalyticsSnapshot(
    best1rm: const [],
    peakWeight: const [],
    volume: const [],
    summary: const ExerciseSummary(best1rm: 0, peakVolume: 0, sessionCount: 0),
    exerciseId: null,
    revision: null,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // RepositoryScope is an inherited widget, so read it after initState.
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
    final series = displayProgressionPoints(context, _snapshot.best1rm);
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
                  // IntrinsicHeight + stretch equalizes card heights when one
                  // label wraps to two lines at narrow widths.
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
                  LineChart(points: series, unit: weightUnitOf(context).symbol),
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

/// Shared movement-pattern display names (avoids duplicating the switch).
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
