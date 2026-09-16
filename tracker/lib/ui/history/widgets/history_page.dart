import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/ui/history/view_models/calendar_view_model.dart';
import 'package:tracker/ui/history/widgets/calendar/history_calendar.dart';
import 'package:tracker/ui/history/widgets/session_detail_page.dart';

/// History overview (Plan.md §1.2) + calendar (Plan.md §2.5).
///
/// Toggles between a chronological session list and an interactive month
/// calendar; either way a session resolves to its full [SessionDetailPage]
/// (Checkpoint 5).
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  Map<int, String> _gymNames = const {};
  Stream<List<WorkoutSession>>? _stream;
  final _calendar = CalendarViewModel();
  int _selectedTab = 0;
  TrackerRepository? _repository;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Keep the stream and presentation model stable across subtab rebuilds.
    final repository = RepositoryScope.maybeOf(context);
    if (!identical(repository, _repository)) {
      _repository = repository;
      _stream = repository?.sessions.watchAll();
      _calendar.updateSessions(const []);
      _gymNames = const {};
      _loadGyms(repository);
    }
  }

  Future<void> _loadGyms(TrackerRepository? repository) async {
    final gyms = await repository?.gyms.getAll() ?? const [];
    if (!mounted || !identical(repository, _repository)) return;
    setState(() {
      _gymNames = {for (final g in gyms) g.id: g.name};
    });
  }

  @override
  void dispose() {
    _calendar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WorkoutSession>>(
      key: ObjectKey(_repository),
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasData && !snapshot.hasError) {
          _calendar.updateSessions(snapshot.data!);
        }
        return CustomScrollView(slivers: _buildSlivers(context, snapshot));
      },
    );
  }

  List<Widget> _buildSlivers(
    BuildContext context,
    AsyncSnapshot<List<WorkoutSession>> snapshot,
  ) {
    final slivers = <Widget>[CustomAppBar(context, title: 'History')];

    if (snapshot.hasError) {
      slivers.add(
        const SliverFillRemaining(
          hasScrollBody: false,
          child: _HistoryMessage(message: 'Could not load workout history.'),
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
    } else if ((snapshot.data ?? const <WorkoutSession>[]).isEmpty) {
      slivers.add(
        const SliverFillRemaining(hasScrollBody: false, child: _EmptyHistory()),
      );
    } else {
      final sessions = snapshot.data ?? const <WorkoutSession>[];
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          sliver: SliverToBoxAdapter(
            child: FTabs(
              control: FTabControl.lifted(
                index: _selectedTab,
                onChange: (index) => setState(() => _selectedTab = index),
              ),
              children: [
                .entry(
                  label: const Text('List'),
                  child: _sessionList(context, sessions),
                ),
                .entry(
                  label: const Text('Calendar'),
                  child: HistoryCalendar(
                    model: _calendar,
                    sessions: sessions,
                    gymNames: _gymNames,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return slivers;
  }

  Widget _sessionList(BuildContext context, List<WorkoutSession> sessions) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        return _SessionTile(
          session: session,
          gymName: session.gymId == null ? null : _gymNames[session.gymId],
        );
      },
    );
  }
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: FCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(FLucideIcons.circleAlert),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    ),
  );
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(FLucideIcons.history, size: 48),
          SizedBox(height: 12),
          Text('No workouts logged yet'),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, this.gymName});

  final WorkoutSession session;
  final String? gymName;

  @override
  Widget build(BuildContext context) {
    final duration = session.endTime != null
        ? session.endTime!.difference(session.startTime)
        : Duration.zero;
    return FItem.raw(
      onPress: () => pushTo(
        context,
        SessionDetailPage(session: session, gymName: gymName),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(FLucideIcons.footprints),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${session.title}\n${_date(session.startTime)}'
                '${gymName != null ? ' · $gymName' : ''}'
                '\n${plural('set', session.sets.length)} · ${_dur(duration)}',
              ),
            ),
            const Icon(FLucideIcons.chevronRight),
          ],
        ),
      ),
    );
  }

  String _date(DateTime dt) {
    final d = dt.toLocal();
    return '${d.year}-${_p(d.month)}-${_p(d.day)} ${_p(d.hour)}:${_p(d.minute)}';
  }

  String _dur(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
  }

  String _p(int v) => v.toString().padLeft(2, '0');
}
