import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/services/analytics.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/line_chart.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';

/// General progression analytics (Plan.md §2.4): overall strength and volume
/// trends across all exercises, normalized by gym multipliers (§2.3) with
/// warm-up sets excluded (§2.1).
class ProgressionPage extends StatefulWidget {
  const ProgressionPage({super.key});

  @override
  State<ProgressionPage> createState() => _ProgressionPageState();
}

class _ProgressionPageState extends State<ProgressionPage> {
  List<WorkoutSession> _sessions = const [];
  Map<int, double> _multipliers = const {};
  bool _didLoad = false;
  bool _loading = false;
  Object? _loadError;
  final AnalyticsService _analytics = AnalyticsService();
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
    if (!_didLoad) {
      _didLoad = true;
      _loading = true;
      // didChangeDependencies runs during the mount/build phase. Defer the
      // first state update until that phase completes.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final repo = RepositoryScope.maybeOf(context);
      final sessions =
          await repo?.sessions.getAll() ?? const <WorkoutSession>[];
      final gyms = await repo?.gyms.getAll() ?? const [];
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _multipliers = {for (final gym in gyms) gym.id: gym.multiplier};
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
          exerciseId: null,
          revision: sessions.length,
        );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error;
      });
    }
  }

  Widget _content(BuildContext context) {
    if (_loading && _sessions.isEmpty) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(32), child: FCircularProgress()),
      );
    }
    if (_loadError != null && _sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(FLucideIcons.circleAlert),
            const SizedBox(height: 8),
            const Text('Could not load progression data.'),
            FButton(
              variant: .outline,
              onPress: _load,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final theme = context.theme;
    final summary = _snapshot.summary;
    final volume = displayProgressionPoints(context, _snapshot.volume);
    final totalVolume = volume.fold<double>(
      0,
      (sum, point) => sum + point.value,
    );
    final best1rm = displayProgressionPoints(context, _snapshot.best1rm);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // IntrinsicHeight + stretch equalizes card heights when one label
        // wraps to two lines at narrow widths.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _Stat(label: 'Workouts', value: '${summary.sessionCount}'),
              const SizedBox(width: 8),
              _Stat(
                label: 'Best 1RM',
                value: formatWeight(context, summary.best1rm),
              ),
              const SizedBox(width: 8),
              _Stat(
                label: 'Peak volume',
                value: formatWeight(context, summary.peakVolume),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _Stat(
              label: 'Total volume',
              value: formatWeight(context, totalVolume),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Working volume over time',
          style: theme.typography.body.md.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        LineChart(points: volume, unit: weightUnitOf(context).symbol),
        const SizedBox(height: 24),
        Text(
          'Best estimated 1RM over time',
          style: theme.typography.body.md.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        LineChart(points: best1rm, unit: weightUnitOf(context).symbol),
        const SizedBox(height: 16),
        Text(
          'Warm-up sets are excluded; weights are normalized by each '
          'gym\'s multiplier.',
          style: theme.typography.body.xs.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: <Widget>[
        CustomAppBar(context, title: 'Progression'),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _content(context),
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
