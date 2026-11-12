// Records the History first open (and the calendar sheet with a jump to a
// day) with an on-screen frame HUD, for before/after performance videos. Run in profile
// mode so the window shows release-like speed:
//   flutter drive --profile -d windows --dart-define=CAPTURE_LABEL=AFTER \
//     --driver=benchmark/drive/history_calendar_driver.dart \
//     --target=integration_test/capture_history_perf_test.dart
// then record the window with `pwsh ./capture-app-media.ps1 -Mode video`
// (see docs/CAPTURING_MEDIA.md). Create build/captures/.capture-done to end.

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:integration_test/integration_test.dart';
import 'package:isar_community/isar.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/data/services/seed.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/main.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/history/widgets/calendar/history_calendar.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';
import 'package:window_size/window_size.dart';

import '../benchmark/calendar_benchmark_support.dart' show buildSessions;
import '../testing/fakes/in_memory_storage.dart';

const String _label = String.fromEnvironment(
  'CAPTURE_LABEL',
  defaultValue: 'BUILD',
);
const int _sessionCount = 2000;

final GlobalKey<_FrameHudState> _hud = GlobalKey<_FrameHudState>();

/// The newest of [buildSessions]: History lists it first.
bool _listOnScreen() => find.text('Workout 0').evaluate().isNotEmpty;

bool _calendarOnScreen() => find.byType(HistoryCalendar).evaluate().isNotEmpty;

Future<void> main() async {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('capture: history first open with frame HUD', (tester) async {
    if (Platform.isWindows) setWindowTitle('Tracker');

    HydratedBloc.storage = InMemoryStorage();
    final dir = Directory.systemTemp.createTempSync('isar_capture_history');
    final isar = await Isar.open(
      [ExerciseSchema, GymSchema, WorkoutSplitSchema, WorkoutSessionSchema],
      directory: dir.path,
      name: 'isar_capture_history',
    );
    final repo = TrackerRepository(isar);
    await seedExercisesIfNeeded(repo);
    await isar.writeTxn(
      () => isar.workoutSessions.putAll(buildSessions(_sessionCount)),
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepositoryScope(
              repository: repo,
              child: MultiBlocProvider(
                providers: [
                  BlocProvider<WorkoutCubit>(
                    create: (_) => WorkoutCubit(repository: repo),
                  ),
                  BlocProvider<SettingsCubit>(create: (_) => SettingsCubit()),
                ],
                child: const MyApp(),
              ),
            ),
            // Bottom right, clear of the tab bar and the month header.
            Positioned(bottom: 72, right: 12, child: FrameHud(key: _hud)),
          ],
        ),
      ),
    );

    // Time for the recorder to attach, and the user-like pause on the Feed.
    await Future<void>.delayed(const Duration(seconds: 6));

    await _hud.currentState!.track(
      'Tap the History tab (first open)',
      _listOnScreen,
      () => tester
          .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
          .onChange!(1),
    );
    await Future<void>.delayed(const Duration(seconds: 3));

    final calendar = tester.getCenter(
      find.byWidgetPredicate(
        (w) => w is FButton && w.semanticsTooltip == 'Calendar',
      ),
    );
    await _hud.currentState!.track(
      'Tap the calendar',
      _calendarOnScreen,
      () => tester.tapAt(calendar),
    );
    await Future<void>.delayed(const Duration(seconds: 3));

    final day = tester.getCenter(
      find
          .byWidgetPredicate(
            (w) =>
                w is Semantics &&
                (w.properties.label?.startsWith('Workout on') ?? false),
          )
          .first,
    );
    await _hud.currentState!.track(
      'Tap a workout day',
      () => !_calendarOnScreen(),
      () => tester.tapAt(day),
    );
    await Future<void>.delayed(const Duration(seconds: 3));
    _hud.currentState!.idle();

    const doneFile = 'build/captures/.capture-done';
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (!File(doneFile).existsSync() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    await isar.close(deleteFromDisk: true);
  });
}

typedef _FrameMark = ({int frame, int ms, bool hit});

/// Repaints every vsync and shows, for the interaction being tracked, the
/// frame number since the tap and one box per rendered frame until the
/// target screen is up. The top-left marker is yellow for the 700 ms before
/// a tap, magenta from the tap until the target is on screen, then green
/// (grey when idle); the yellow onset aligns the before/after recordings.
class FrameHud extends StatefulWidget {
  const FrameHud({super.key});

  @override
  State<FrameHud> createState() => _FrameHudState();
}

class _FrameHudState extends State<FrameHud>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  String _action = 'Waiting';
  int? _tapFrame;
  Stopwatch _watch = Stopwatch();
  final List<_FrameMark> _marks = <_FrameMark>[];
  _FrameMark? _hit;

  bool _announcing = false;

  bool get _armed => _tapFrame != null && _hit == null;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => setState(() {}))..start();
  }

  void idle() => setState(() {
    _action = 'Done';
    _tapFrame = null;
    _hit = null;
    _marks.clear();
  });

  Future<void> track(
    String action,
    bool Function() visible,
    FutureOr<void> Function() interact,
  ) async {
    setState(() {
      _action = action;
      _announcing = true;
      _tapFrame = null;
      _hit = null;
      _marks.clear();
    });
    await Future<void>.delayed(const Duration(milliseconds: 700));
    _announcing = false;

    final done = Completer<void>();
    void onFrame(Duration _) {
      final mark = (
        frame: PlatformDispatcher.instance.frameData.frameNumber - _tapFrame!,
        ms: _watch.elapsedMilliseconds,
        hit: visible(),
      );
      _marks.add(mark);
      if (mark.hit) {
        _hit = mark;
        done.complete();
      } else {
        SchedulerBinding.instance.addPostFrameCallback(onFrame);
      }
    }

    _tapFrame = PlatformDispatcher.instance.frameData.frameNumber;
    _watch = Stopwatch()..start();
    SchedulerBinding.instance.addPostFrameCallback(onFrame);
    await interact();
    await done.future.timeout(const Duration(seconds: 20));
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const white = TextStyle(color: Colors.white, fontSize: 15, height: 1.3);
    final hit = _hit;
    final Color marker = hit != null
        ? const Color(0xFF00FF00)
        : _armed
        ? const Color(0xFFFF00FF)
        : (_announcing ? const Color(0xFFFFFF00) : const Color(0xFF404040));
    final String counter;
    if (hit != null) {
      counter = 'Frame ${hit.frame}  ·  +${hit.ms} ms';
    } else if (_armed) {
      final frame =
          PlatformDispatcher.instance.frameData.frameNumber - _tapFrame!;
      counter = 'Frame $frame  ·  +${_watch.elapsedMilliseconds} ms';
    } else {
      counter = 'Frame -';
    }

    return IgnorePointer(
      // Fixed size so the marker sits at the same pixels in every state.
      child: Container(
        width: 380,
        height: 190,
        alignment: Alignment.topLeft,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xE6000000),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(width: 26, height: 26, color: marker),
                const SizedBox(width: 10),
                Text(
                  _label,
                  style: white.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'profile · $_sessionCount sessions',
                  style: white.copyWith(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(_action, style: white),
            Text(
              counter,
              style: white.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final m in _marks.take(24))
                  Container(
                    width: 52,
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    color: m.hit
                        ? const Color(0xFF1B9E3E)
                        : const Color(0xFFB45309),
                    child: Text(
                      '#${m.frame}\n+${m.ms}ms',
                      textAlign: TextAlign.center,
                      style: white.copyWith(fontSize: 11, height: 1.2),
                    ),
                  ),
              ],
            ),
            if (hit != null) ...[
              const SizedBox(height: 6),
              Text(
                'On screen after ${hit.frame} frame${hit.frame == 1 ? '' : 's'}'
                ' (${hit.ms} ms)',
                style: white.copyWith(
                  color: const Color(0xFF4ADE80),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
