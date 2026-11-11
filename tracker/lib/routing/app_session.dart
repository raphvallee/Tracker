import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/data/services/app_log.dart';
import 'package:tracker/data/services/sample_data.dart';
import 'package:tracker/data/services/test_mode.dart';
import 'package:tracker/domain/models/graph_config.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/core/ui/test_mode_scope.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/splits/view_models/split_drafts_cubit.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

/// The repository and cubits the app runs on: the real ones, or test
/// mode's sample ones. Switching builds [app] again from scratch on the
/// other set (every tab back at its root), so nothing of one leaks into the
/// other; the real cubits saved their state as they went and read it back.
class AppSession extends StatefulWidget {
  const AppSession({
    super.key,
    required this.repository,
    required this.storage,
    required this.documentsPath,
    this.sandbox,
    this.openSandbox = TestMode.openSandbox,
    required this.app,
  });

  final TrackerRepository repository;
  final Storage storage;
  final String documentsPath;

  /// Test mode's database when the app starts in test mode.
  final (TrackerRepository, SampleData)? sandbox;

  /// Opens a fresh sample database; tests open theirs elsewhere.
  final Future<(TrackerRepository, SampleData)> Function() openSandbox;

  final Widget app;

  @override
  State<AppSession> createState() => _AppSessionState();
}

class _AppSessionState extends State<AppSession> {
  TrackerRepository? _sandbox;
  bool _busy = false;

  /// Bumped on every switch or reset: a new key builds everything anew.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    if (widget.sandbox case (final repo, final sample)?) {
      _sandbox = repo;
      HydratedBloc.storage = sandboxStorage(widget.storage, sample);
    }
  }

  Future<void> _setEnabled(bool enabled) async {
    if (_busy || enabled == (_sandbox != null)) return;
    if (enabled) return _open();
    setState(() => _busy = true);
    final old = _sandbox!;
    HydratedBloc.storage = widget.storage;
    setState(() {
      _sandbox = null;
      _generation++;
      _busy = false;
    });
    unawaited(_close(old));
    await TestMode.remember(widget.documentsPath, on: false);
  }

  /// Opens a fresh sample database and moves onto it; the one it replaces,
  /// if any, is closed once nothing reads it.
  Future<void> _open() async {
    if (_busy) return;
    setState(() => _busy = true);
    final old = _sandbox;
    try {
      final (repo, sample) = await widget.openSandbox();
      if (!mounted) return;
      HydratedBloc.storage = sandboxStorage(widget.storage, sample);
      setState(() {
        _sandbox = repo;
        _generation++;
      });
      await TestMode.remember(widget.documentsPath, on: true);
      if (old != null) unawaited(_close(old));
    } catch (error, stackTrace) {
      AppLog.error('test-mode', error, stackTrace);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close(TrackerRepository repo) async {
    // The old screens stop reading it when this frame ends.
    await WidgetsBinding.instance.endOfFrame;
    try {
      await TestMode.closeSandbox(repo);
    } catch (error, stackTrace) {
      AppLog.error('test-mode', error, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = _sandbox ?? widget.repository;
    return TestModeScope(
      enabled: _sandbox != null,
      busy: _busy,
      setEnabled: _setEnabled,
      reset: _open,
      child: KeyedSubtree(
        key: ValueKey(_generation),
        child: RepositoryProvider<TrackerRepository>.value(
          value: repository,
          child: RepositoryScope(
            repository: repository,
            child: MultiBlocProvider(
              providers: [
                BlocProvider<WorkoutCubit>(
                  create: (_) => WorkoutCubit(repository: repository),
                  lazy: false,
                ),
                BlocProvider<SettingsCubit>(
                  create: (_) => SettingsCubit(),
                  lazy: false,
                ),
                BlocProvider<SplitDraftsCubit>(
                  create: (_) => SplitDraftsCubit(repository: repository),
                  lazy: false,
                ),
              ],
              child: widget.app,
            ),
          ),
        ),
      ),
    );
  }
}

/// Test mode's saved state, in memory: the real settings (units, number
/// entry...) with the sample splits current and a few graphs to look at;
/// no workout running, no drafts.
@visibleForTesting
MemoryStorage sandboxStorage(Storage real, SampleData sample) {
  var settings = SettingsState();
  try {
    final saved = real.read('SettingsCubit');
    if (saved is Map) {
      settings = SettingsState.fromJson(Map<String, dynamic>.from(saved));
    }
  } catch (_) {}
  final ids = sample.exerciseIds;
  settings = settings.copyWith(
    currentSplitId: sample.currentSplitId,
    splitsUsedAt: {sample.previousSplitId: sample.previousSplitUsedAt},
    graphRange: GraphTimeframe.last90Days,
    graphs: [
      for (final (name, metric) in const [
        ('Bench Press', GraphMetric.best1rm),
        ('Bench Press', GraphMetric.record1rm),
        ('Squat', GraphMetric.record1rm),
        ('Deadlift', GraphMetric.peakWeight),
        ('Squat', GraphMetric.volume),
      ])
        if (ids[name] case final id?)
          GraphConfig(exerciseId: id, metric: metric),
    ],
  );
  return MemoryStorage({'SettingsCubit': settings.toJson()});
}
