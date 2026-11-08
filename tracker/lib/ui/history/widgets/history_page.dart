import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/data/services/app_log.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/routing/tab_navigation.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/ui/history/widgets/calendar/calendar_grid.dart';
import 'package:tracker/ui/history/widgets/calendar/history_calendar.dart';
import 'package:tracker/ui/history/widgets/session_detail_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  static const int _calendarTab = 0;
  static const int _listTab = 1;

  TrackerRepository? _repo;
  StreamSubscription<void>? _changes;
  bool _didLoad = false;
  bool _active = true;
  bool _stale = false;
  Object? _error;

  Map<int, String> _gymNames = const {};
  WorkoutDateIndex _index = WorkoutDateIndex(const []);

  /// Full sessions for the List tab, read only while it is (or was last)
  /// shown; the calendar works from start times alone.
  List<WorkoutSession>? _sessions;
  int _tab = _calendarTab;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _active = TabVisibilityScope.isActiveOf(context);
    // RepositoryScope is an inherited widget, so read it here (after initState).
    if (!_didLoad) {
      _didLoad = true;
      _repo = RepositoryScope.maybeOf(context);
      _changes = _repo?.sessions.watchChanges().listen(
        (_) => _onSessionsChanged(),
        onError: _onLoadError,
      );
      // Synchronous reads, so the very first frame already shows the
      // calendar instead of a loading spinner.
      _load(includeGyms: true);
    } else if (_active && _stale) {
      _load();
    }
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  void _onSessionsChanged() {
    // History is built ahead of time while hidden: defer the reload to when
    // the tab is shown instead of rebuilding offstage on every save.
    if (!_active) {
      _stale = true;
      return;
    }
    setState(_load);
  }

  void _onLoadError(Object error, StackTrace stackTrace) {
    AppLog.error('history', error, stackTrace);
    if (mounted) setState(() => _error = error);
  }

  void _load({bool includeGyms = false}) {
    _stale = false;
    final repo = _repo;
    if (repo == null) return;
    try {
      if (includeGyms) {
        _gymNames = {for (final g in repo.gyms.getAllSync()) g.id: g.name};
      }
      _index = WorkoutDateIndex(repo.sessions.getStartTimesSync());
      // An emptied history drops the tab bar; it comes back on Calendar.
      if (_index.isEmpty) _tab = _calendarTab;
      _sessions = _tab == _listTab ? repo.sessions.getAllSync() : null;
      _error = null;
    } on Object catch (error, stackTrace) {
      AppLog.error('history', error, stackTrace);
      _error = error;
    }
  }

  void _selectTab(int tab) {
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      if (tab == _listTab && _sessions == null) _load();
    });
  }

  List<WorkoutSession> _sessionsOn(DateTime day) =>
      _repo?.sessions.getOnLocalDaySync(day) ?? const [];

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(slivers: _buildSlivers(context));
  }

  List<Widget> _buildSlivers(BuildContext context) {
    final slivers = <Widget>[CustomAppBar(context, title: 'History')];

    if (_error != null) {
      slivers.add(
        const SliverFillRemaining(
          hasScrollBody: false,
          child: _HistoryMessage(message: 'Could not load workout history.'),
        ),
      );
    } else if (_index.isEmpty) {
      slivers.add(
        const SliverFillRemaining(hasScrollBody: false, child: _EmptyHistory()),
      );
    } else {
      final theme = context.theme;
      slivers
        ..add(
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            // Tab bar only: the selected tab's content is its own sliver
            // below, so the List tab can be a lazy SliverList.
            sliver: SliverToBoxAdapter(
              child: FTabs(
                control: .managed(onChange: _selectTab),
                onPress: _selectTab,
                children: [
                  .entry(
                    label: const Text('Calendar'),
                    child: const SizedBox.shrink(),
                  ),
                  .entry(
                    label: const Text('List'),
                    child: const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        )
        ..add(
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            // The text style FTabs gives its own content.
            sliver: DefaultTextStyle(
              style: theme.typography.body.md.copyWith(
                color: theme.colors.foreground,
              ),
              child: _tab == _calendarTab
                  ? SliverToBoxAdapter(
                      child: HistoryCalendar(
                        index: _index,
                        sessionsOn: _sessionsOn,
                        gymNames: _gymNames,
                      ),
                    )
                  : _sessionList(_sessions ?? const []),
            ),
          ),
        );
    }
    return slivers;
  }

  Widget _sessionList(List<WorkoutSession> sessions) {
    return SliverList.builder(
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
