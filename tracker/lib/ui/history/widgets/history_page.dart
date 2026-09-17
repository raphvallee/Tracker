import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/routing/tab_navigation.dart';
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
  StreamSubscription<List<WorkoutSession>>? _listSubscription;
  List<WorkoutSession> _sessions = const [];
  bool _listLoading = false;
  Object? _listError;
  int _listGeneration = 0;
  int _gymGeneration = 0;
  final _calendar = CalendarViewModel(observeAppLifecycle: false);
  late final AppLifecycleListener _lifecycleListener;
  bool _tabActive = true;
  bool _appVisible = true;
  bool _active = false;
  int _selectedTab = 0;
  TrackerRepository? _repository;

  @override
  void initState() {
    super.initState();
    final state = WidgetsBinding.instance.lifecycleState;
    _appVisible =
        state != AppLifecycleState.hidden &&
        state != AppLifecycleState.paused &&
        state != AppLifecycleState.detached;
    _calendar.setHistoryActive(false);
    _lifecycleListener = AppLifecycleListener(
      onStateChange: (state) {
        // Losing focus alone is not suspension. After suspension, wait for resume.
        if (state == AppLifecycleState.inactive) return;
        final visible = state == AppLifecycleState.resumed;
        if (_appVisible == visible) return;
        setState(() {
          _appVisible = visible;
          _syncActive();
        });
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tabActive = TabVisibilityScope.isActiveOf(context);
    final repository = RepositoryScope.maybeOf(context);
    if (!identical(repository, _repository)) {
      // Suspend first, so a replacement cannot briefly attach the old mode or
      // start queries before the new visibility dependency has been applied.
      _suspend();
      _repository = repository;
      _calendar.bindRepository(repository?.sessions);
      _gymNames = const {};
    }
    _syncActive();
  }

  void _suspend() {
    _active = false;
    _gymGeneration++;
    _cancelList();
    _calendar.setHistoryActive(false);
  }

  void _syncActive() {
    final active = _tabActive && _appVisible;
    if (_active == active) return;
    if (!active) {
      _suspend();
      return;
    }
    _active = true;
    _calendar.setHistoryActive(true);
    if (_selectedTab == 0) _startList();
    _loadGyms(_repository);
  }

  Future<void> _loadGyms(TrackerRepository? repository) async {
    final generation = ++_gymGeneration;
    try {
      final gyms = await repository?.gyms.getAll() ?? const [];
      if (!mounted ||
          !_active ||
          generation != _gymGeneration ||
          !identical(repository, _repository)) {
        return;
      }
      setState(() {
        _gymNames = {for (final g in gyms) g.id: g.name};
      });
    } catch (_) {
      // Gym labels are optional; a failed lookup must not break history.
    }
  }

  void _cancelList() {
    _listGeneration++;
    unawaited(_listSubscription?.cancel());
    _listSubscription = null;
    _sessions = const []; // Do not retain full-history payloads in Calendar.
    _listError = null;
    _listLoading = false;
  }

  void _startList() {
    _cancelList();
    final repository = _repository;
    if (!_active || repository == null) return;
    final generation = _listGeneration;
    bool current() =>
        mounted &&
        _active &&
        _selectedTab == 0 &&
        generation == _listGeneration &&
        identical(repository, _repository);
    _listLoading = true;
    _listSubscription = repository.sessions.watchAll().listen(
      (sessions) {
        if (!current()) return;
        setState(() {
          _sessions = sessions;
          _listLoading = false;
          _listError = null;
        });
      },
      onError: (Object error) {
        if (!current()) return;
        setState(() {
          _listError = error;
          _listLoading = false;
        });
      },
    );
  }

  void _selectTab(int index) {
    if (index == _selectedTab) return;
    setState(() {
      _selectedTab = index;
      if (index == 1) _cancelList();
      _calendar.setCalendarMode(index == 1);
      if (index == 0) _startList();
    });
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _suspend();
    _calendar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        CustomAppBar(context, title: 'History'),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          sliver: SliverToBoxAdapter(
            child: FTabs(
              control: FTabControl.lifted(
                index: _selectedTab,
                onChange: _selectTab,
              ),
              children: [
                .entry(label: const Text('List'), child: _listBody(context)),
                .entry(
                  label: const Text('Calendar'),
                  child: HistoryCalendar(model: _calendar, gymNames: _gymNames),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _listBody(BuildContext context) {
    if (_listError != null) {
      return Column(
        children: [
          const _HistoryMessage(message: 'Could not load workout history.'),
          TextButton(
            onPressed: () => setState(_startList),
            child: const Text('Retry history'),
          ),
        ],
      );
    }
    if (_listLoading) return const Center(child: CircularProgressIndicator());
    if (_sessions.isEmpty) return const _EmptyHistory();
    return _sessionList(context, _sessions);
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
