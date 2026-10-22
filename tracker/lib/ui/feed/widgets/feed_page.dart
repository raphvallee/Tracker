import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:tracker/data/services/app_log.dart';
import 'package:tracker/ui/core/ui/app_dialog.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/routing/tab_navigation.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/ui/analytics/widgets/graph_editor.dart';
import 'package:tracker/ui/analytics/widgets/progression_page.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/feed/view_models/feed_cubit.dart';
import 'package:tracker/ui/feed/widgets/feed_page_graph_card.dart';
import 'package:tracker/ui/history/widgets/session_detail_page.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/ui/settings/widgets/settings_page.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

/// Personal activity feed built from completed workout sessions.
class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  FeedCubit? _cubit;
  Map<int, String> _gymNames = const {};
  List<WorkoutSession> _allSessions = const [];
  List<Exercise> _exercises = const [];
  Map<int, double> _multipliers = const {};
  bool _didLoad = false;
  bool _wasActive = true;
  Object? _analyticsError;

  SettingsCubit? get _settings => SettingsCubit.maybeOf(context);

  Future<void> _loadAnalyticsData() async {
    final repo = RepositoryScope.maybeOf(context);
    if (repo == null) return;
    try {
      final results = await Future.wait([
        repo.sessions.getAll(),
        repo.exercises.getAll(),
        repo.gyms.getAll(),
      ]);
      if (!mounted) return;
      setState(() {
        _allSessions = results[0] as List<WorkoutSession>;
        _exercises = results[1] as List<Exercise>;
        final gyms = results[2] as List<dynamic>;
        _multipliers = {
          for (final gym in gyms) gym.id as int: gym.multiplier as double,
        };
        _gymNames = {for (final gym in gyms) gym.id as int: gym.name as String};
        _analyticsError = null;
      });
    } catch (error, stackTrace) {
      AppLog.error('feed-analytics', error, stackTrace);
      if (!mounted) return;
      // Without this the graph cards silently render as "No data yet".
      setState(() => _analyticsError = error);
    }
  }

  Future<void> _editGraph({int? index}) async {
    final settings = _settings;
    if (settings == null) return;
    final result = await GraphEditor.show(
      context,
      initial: index == null ? null : settings.state.graphs[index],
      exercises: _exercises,
    );
    if (!mounted || result == null) return;
    if (index == null) {
      settings.addGraph(result);
    } else {
      settings.updateGraph(index, result);
    }
  }

  Future<void> _deleteGraph(int index) async {
    final settings = _settings;
    if (settings == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete graph?',
      message:
          'Remove "${settings.state.graphs[index].title}" from your '
          'analytics? You can recreate it with "Add graph".',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!mounted || !confirmed) return;
    settings.removeGraph(index);
  }

  Widget _analyticsSection(BuildContext context) {
    final settings = _settings;
    final header = Row(
      children: [
        Expanded(
          child: Text(
            'Analytics',
            style: context.theme.typography.body.xl.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        FButton(
          variant: .ghost,
          onPress: _editGraph,
          prefix: const Icon(FLucideIcons.plus),
          child: const Text('Add graph'),
        ),
      ],
    );
    if (settings == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [header],
        ),
      );
    }
    // BlocBuilder so a saved graph appears immediately: `context.read`
    // alone never re-renders when the settings state changes.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: BlocBuilder<SettingsCubit, SettingsState>(
        bloc: settings,
        builder: (context, state) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            if (_analyticsError != null)
              _FeedMessage(
                icon: FLucideIcons.circleAlert,
                message: 'Could not load analytics.',
                action: FButton(
                  variant: .ghost,
                  onPress: _loadAnalyticsData,
                  child: const Text('Retry'),
                ),
              )
            else
              for (var i = 0; i < state.graphs.length; i++)
                FeedGraphCard(
                  config: state.graphs[i],
                  sessions: _allSessions,
                  multipliers: _multipliers,
                  exerciseName: state.graphs[i].exerciseId == null
                      ? 'All exercises'
                      : _exercises
                                .where(
                                  (e) => e.id == state.graphs[i].exerciseId,
                                )
                                .map((e) => e.title)
                                .firstOrNull ??
                            'Exercise',
                  onEdit: () => _editGraph(index: i),
                  onDelete: () => _deleteGraph(i),
                ),
          ],
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoad) {
      _didLoad = true;
      final repo = RepositoryScope.maybeOf(context);
      if (repo != null) {
        _cubit = FeedCubit(repository: repo)..load();
      }
      _loadGyms();
      _loadAnalyticsData();
    }
    // Tabs stay mounted, so returning to Feed must re-read sessions and gyms
    // that were edited or deleted on another tab.
    final isActive = TabVisibilityScope.isActiveOf(context);
    if (isActive && !_wasActive) _loadAnalyticsData();
    _wasActive = isActive;
  }

  @override
  void dispose() {
    _cubit?.close();
    super.dispose();
  }

  Future<void> _loadGyms() async {
    final gyms =
        await RepositoryScope.maybeOf(context)?.gyms.getAll() ?? const [];
    if (!mounted) return;
    setState(() => _gymNames = {for (final gym in gyms) gym.id: gym.name});
  }

  @override
  Widget build(BuildContext context) {
    final cubit = _cubit;
    // Without a repository scope (isolate tests) there is nothing to watch:
    // render the empty feed directly.
    if (cubit == null) {
      return _buildBody(context, const FeedState(status: FeedStatus.ready));
    }
    return BlocBuilder<FeedCubit, FeedState>(
      bloc: cubit,
      builder: (context, state) => _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, FeedState state) {
    final slivers = <Widget>[
      CustomAppBar(
        context,
        title: 'Feed',
        actionButton: (
          title: 'Settings',
          onPressed: () => pushTo(context, const SettingsPage()),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            'Recent activity',
            style: context.theme.typography.body.xl.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ];
    switch (state.status) {
      case FeedStatus.error:
        slivers.add(
          SliverToBoxAdapter(
            child: _FeedMessage(
              icon: FLucideIcons.circleAlert,
              message: 'Could not load recent activity.',
              action: FButton(
                variant: .ghost,
                onPress: () => _cubit?.retry(),
                child: const Text('Retry'),
              ),
            ),
          ),
        );
      case FeedStatus.loading:
        slivers.add(
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: FCircularProgress()),
          ),
        );
      case FeedStatus.ready:
        final sessions = state.sessions;
        if (sessions.isEmpty) {
          slivers.add(const SliverToBoxAdapter(child: _FeedEmpty()));
        } else {
          slivers.add(
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.builder(
                itemCount: sessions.length,
                itemBuilder: (context, index) => _ActivityCard(
                  session: sessions[index],
                  gymName: sessions[index].gymId == null
                      ? null
                      : _gymNames[sessions[index].gymId],
                  onReturn: _loadAnalyticsData,
                ),
              ),
            ),
          );
        }
    }
    slivers.add(
      BlocBuilder<WorkoutCubit, WorkoutState>(
        builder: (context, state) {
          if (!state.isInProgress) return const SliverToBoxAdapter();
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: FButton(
                onPress: () =>
                    HomePageSingleton().changeTab(TabName.currentWorkout),
                prefix: const Icon(FLucideIcons.dumbbell),
                child: const Text('Go to Current Workout'),
              ),
            ),
          );
        },
      ),
    );
    slivers.add(SliverToBoxAdapter(child: _analyticsSection(context)));
    slivers.add(
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          child: FItem(
            prefix: const Icon(FLucideIcons.chartLine),
            title: const Text('Progression'),
            subtitle: const Text(
              'Strength and volume trends across all exercises',
            ),
            suffix: const Icon(FLucideIcons.chevronRight),
            onPress: () => pushTo(context, const ProgressionPage()),
          ),
        ),
      ),
    );
    return CustomScrollView(slivers: slivers);
  }
}

class _FeedEmpty extends StatelessWidget {
  const _FeedEmpty();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: FCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: const [
            Icon(FLucideIcons.dumbbell, size: 40),
            SizedBox(height: 8),
            Text('No workouts logged yet.'),
            SizedBox(height: 4),
            Text('Complete a workout to see activity here.'),
          ],
        ),
      ),
    ),
  );
}

class _FeedMessage extends StatelessWidget {
  const _FeedMessage({required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => FCard(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
          ?action,
        ],
      ),
    ),
  );
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.session,
    required this.onReturn,
    this.gymName,
  });

  final WorkoutSession session;
  final String? gymName;
  final Future<void> Function() onReturn;

  @override
  Widget build(BuildContext context) {
    final working = session.sets.where((set) => !set.isWarmup);
    final volume = working.fold<double>(
      0,
      (sum, set) => sum + set.weight * set.reps,
    );
    final duration = session.endTime == null
        ? Duration.zero
        : session.endTime!.difference(session.startTime);
    return FItem.raw(
      onPress: () async {
        await pushTo(
          context,
          SessionDetailPage(session: session, gymName: gymName),
        );
        await onReturn();
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(FLucideIcons.circleCheck),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${session.title}\n${_date(session.startTime)}${gymName == null ? '' : ' · $gymName'}\n'
                '${plural('set', session.sets.length)} · ${_duration(duration)} · ${formatWeight(context, volume)}',
              ),
            ),
            const Icon(FLucideIcons.chevronRight),
          ],
        ),
      ),
    );
  }

  String _date(DateTime value) {
    final date = value.toLocal();
    return '${date.year}-${_pad(date.month)}-${_pad(date.day)}';
  }

  String _duration(Duration value) => value.inHours > 0
      ? '${value.inHours}h ${value.inMinutes % 60}m'
      : '${value.inMinutes}m';

  String _pad(int value) => value.toString().padLeft(2, '0');
}
