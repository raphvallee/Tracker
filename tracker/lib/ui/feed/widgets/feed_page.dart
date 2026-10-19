import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/routing/tab_navigation.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/ui/analytics/widgets/graph_editor.dart';
import 'package:tracker/ui/analytics/widgets/progression_page.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
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
  Stream<List<WorkoutSession>>? _stream;
  Map<int, String> _gymNames = const {};
  List<WorkoutSession> _allSessions = const [];
  List<Exercise> _exercises = const [];
  Map<int, double> _multipliers = const {};
  bool _didLoad = false;

  SettingsCubit? get _settings => SettingsCubit.maybeOf(context);

  Future<void> _loadAnalyticsData() async {
    final repo = RepositoryScope.maybeOf(context);
    if (repo == null) return;
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
    });
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
        TextButton.icon(
          onPressed: _editGraph,
          icon: const Icon(FLucideIcons.plus),
          label: const Text('Add graph'),
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
            for (var i = 0; i < state.graphs.length; i++)
              FeedGraphCard(
                config: state.graphs[i],
                sessions: _allSessions,
                multipliers: _multipliers,
                exerciseName: state.graphs[i].exerciseId == null
                    ? 'All exercises'
                    : _exercises
                              .where((e) => e.id == state.graphs[i].exerciseId)
                              .map((e) => e.title)
                              .firstOrNull ??
                          'Exercise',
                onEdit: () => _editGraph(index: i),
                onDelete: () => settings.removeGraph(i),
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
      _stream = repo?.sessions.watchRecent(limit: 3);
      _loadGyms();
      _loadAnalyticsData();
    }
  }

  Future<void> _loadGyms() async {
    final gyms =
        await RepositoryScope.maybeOf(context)?.gyms.getAll() ?? const [];
    if (!mounted) return;
    setState(() => _gymNames = {for (final gym in gyms) gym.id: gym.name});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WorkoutSession>>(
      stream: _stream,
      builder: (context, snapshot) {
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
        if (_stream == null) {
          slivers.add(const SliverToBoxAdapter(child: _FeedEmpty()));
        } else if (snapshot.hasError) {
          slivers.add(
            SliverToBoxAdapter(
              child: _FeedMessage(
                icon: FLucideIcons.circleAlert,
                message: 'Could not load recent activity.',
                action: TextButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ),
            ),
          );
        } else if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          slivers.add(
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        } else {
          final sessions = snapshot.data ?? const <WorkoutSession>[];
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
                  ),
                ),
              ),
            );
          }
        }
        slivers.add(
          BlocBuilder<WorkoutCubit, WorkoutState>(
            builder: (context, state) {
              if (state.isInProgress) return const SliverToBoxAdapter();
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
      },
    );
  }
}

class _FeedEmpty extends StatelessWidget {
  const _FeedEmpty();

  @override
  Widget build(BuildContext context) => FCard(
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
  const _ActivityCard({required this.session, this.gymName});

  final WorkoutSession session;
  final String? gymName;

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
      onPress: () => pushTo(
        context,
        SessionDetailPage(session: session, gymName: gymName),
      ),
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
