import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/data/services/app_log.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/ui/core/ui/app_dialog.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/core/ui/keyboard_inset.dart';
import 'package:tracker/ui/core/ui/max_width.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/core/ui/set_type_chip.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/ui/history/widgets/session_edit_page.dart';

/// Full view of a single past [WorkoutSession] (Plan.md §1.2): header stats
/// plus every logged set with its warm-up/working indicator and working volume.
///
/// Reached from the history list and the calendar's day logs (Checkpoint 5).
/// Offers Edit (a past-session editor that persists through the session
/// repository) and Delete (with a confirmation dialog).
class SessionDetailPage extends StatefulWidget {
  const SessionDetailPage({super.key, required this.session, this.gymName});

  final WorkoutSession session;

  /// Resolved gym display name (nullable - a session may have no gym).
  final String? gymName;

  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  // Tracks edits/deletes made after this page was opened; the widget's session
  // is just the snapshot the caller had.
  late WorkoutSession _session;
  String? _gymName;
  Map<int, String> _exerciseNames = const {};
  bool _didLoad = false;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _gymName = widget.gymName;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // RepositoryScope is an inherited widget, so read it after initState.
    if (!_didLoad) {
      _didLoad = true;
      _loadExerciseNames();
    }
  }

  Future<void> _loadExerciseNames() async {
    final repo = RepositoryScope.maybeOf(context);
    final exercises = await repo?.exercises.getAll() ?? const [];
    if (!mounted) return;
    setState(() {
      _exerciseNames = {for (final e in exercises) e.id: e.title};
    });
  }

  Future<void> _resolveGymName() async {
    final gymId = _session.gymId;
    if (gymId == null) {
      setState(() => _gymName = null);
      return;
    }
    final gym = await RepositoryScope.maybeOf(context)?.gyms.getById(gymId);
    if (!mounted) return;
    setState(() => _gymName = gym?.name);
  }

  /// Opens the editor, applies its draft optimistically and persists through
  /// the repository (error-surfacing contract for writes, mirroring the
  /// workout cubit: a failed save keeps the edited view and toasts once).
  Future<void> _edit() async {
    final repo = RepositoryScope.maybeOf(context);
    final updated = await pushTo(context, SessionEditPage(session: _session));
    if (updated == null) return;
    setState(() => _session = updated);
    if (repo != null) unawaited(_persist(repo, updated));
    await _resolveGymName();
  }

  Future<void> _persist(TrackerRepository repo, WorkoutSession updated) async {
    try {
      await repo.sessions.put(updated);
      await _refresh(repo);
    } catch (error, stackTrace) {
      AppLog.error('history-edit', error, stackTrace);
      if (!mounted) return;
      showFToast(
        context: context,
        title: const Text('Could not save the changes.'),
        duration: const Duration(seconds: 4),
      );
    }
  }

  /// Re-reads the session after a save lands so the page reflects what was
  /// actually persisted (and keeps gym names fresh if the gym was edited).
  Future<void> _refresh(TrackerRepository repo) async {
    final fresh = await repo.sessions.getById(_session.id);
    if (!mounted) return;
    setState(() => _session = fresh ?? _session);
    await _resolveGymName();
  }

  /// Deletes the session (and its embedded sets) permanently after
  /// confirmation, pops back to the list immediately and removes the record
  /// through the repository in the background (the lists refresh via their
  /// watch streams).
  Future<void> _delete() async {
    final repo = RepositoryScope.maybeOf(context);
    if (repo == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete session?',
      message:
          'This permanently removes "${_session.title}" and all its sets '
          'from history.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    // Let the dialog route finish leaving the navigator before popping this
    // page, so pop() lands on the detail route and not the dialog.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;
    // This page's context is gone once it pops; the navigator's context lives
    // under the app-level FToaster, so the failure toast can still show.
    final navigator = Navigator.of(context);
    navigator.pop();
    try {
      final deleted = await repo.sessions.delete(_session.id);
      if (!deleted) throw StateError('session ${_session.id} was not found');
    } catch (error, stackTrace) {
      AppLog.error('history-delete', error, stackTrace);
      _showDeleteFailure(navigator);
    }
  }

  static void _showDeleteFailure(NavigatorState navigator) {
    showFToast(
      context: navigator.context,
      title: const Text('Could not delete the session.'),
      duration: const Duration(seconds: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final session = _session;
    final workingSets = session.sets.where((s) => !s.isWarmup).toList();
    final workingVolume = workingSets.fold<double>(
      0,
      (sum, s) => sum + s.weight * s.reps,
    );

    return CustomScrollView(
      slivers: <Widget>[
        CustomAppBar(
          context,
          title: session.title,
          actionButton: (title: 'Edit', onPressed: _edit),
        ),
        SliverToBoxAdapter(
          child: MaxWidth(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _HeaderCard(session: session, gymName: _gymName),
                  const SizedBox(height: 12),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _Stat(label: 'Sets', value: '${session.sets.length}'),
                        const SizedBox(width: 12),
                        _Stat(
                          label: 'Working volume',
                          value: formatWeight(context, workingVolume),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sets',
                    style: theme.typography.body.md.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (session.sets.isEmpty)
                    const Text('No sets were logged in this session.')
                  else
                    for (final set in session.sets)
                      _SetRow(
                        name:
                            _exerciseNames[set.exerciseId] ??
                            'Exercise ${set.exerciseId}',
                        set: set,
                      ),
                  // Bottom padding grows by the keyboard height plus the
                  // reveal gap so the delete action can scroll above the
                  // keyboard (see keyboard_inset).
                  const SizedBox(height: 24),
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: keyboardClearanceOf(context),
                    ),
                    child: FButton(
                      variant: .destructive,
                      size: .lg,
                      onPress: _delete,
                      prefix: const Icon(FLucideIcons.trash2),
                      child: const Text('Delete session'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.session, this.gymName});

  final WorkoutSession session;
  final String? gymName;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final duration = session.endTime != null
        ? session.endTime!.difference(session.startTime)
        : Duration.zero;
    final d = session.startTime.toLocal();
    return FCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _date(d),
              style: theme.typography.body.md.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              [?gymName, _duration(duration)].join(' · '),
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _date(DateTime d) =>
      '${d.year}-${_p(d.month)}-${_p(d.day)} ${_p(d.hour)}:${_p(d.minute)}';

  String _p(int v) => v.toString().padLeft(2, '0');

  String _duration(Duration dur) {
    if (dur.inHours > 0) return '${dur.inHours}h ${dur.inMinutes % 60}m';
    return '${dur.inMinutes}m';
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
                style: theme.typography.body.xl.copyWith(
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

class _SetRow extends StatelessWidget {
  const _SetRow({required this.name, required this.set});

  final String name;
  final WorkoutSet set;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: FItem(
        prefix: SetTypeChip(isWarmup: set.isWarmup),
        title: Text(name),
        subtitle: Text(
          '${formatWeight(context, set.weight)} × ${formatReps(set.reps)}',
        ),
      ),
    );
  }
}
