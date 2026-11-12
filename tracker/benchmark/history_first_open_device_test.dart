// Shell-level History benchmark: the real app (MyApp + Isar) from the
// bottom-nav tap to the workout list on screen, plus the History interactions
// that must not regress (the calendar sheet and a jump to a day). Engine FrameTimings, profile mode. Run from tracker/:
//   flutter drive --profile -d windows --driver=benchmark/drive/history_calendar_driver.dart --target=benchmark/history_first_open_device_test.dart
// Prints one `BENCH history_shell | ...` line per scenario.
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:integration_test/integration_test.dart';
import 'package:isar_community/isar.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/main.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/history/widgets/calendar/history_calendar.dart';
import 'package:tracker/ui/history/widgets/history_page.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

import '../testing/fakes/in_memory_storage.dart';
import '../testing/frame_probe.dart';
import 'calendar_benchmark_support.dart';

const int _iterations = 10;

/// Time on the Feed tab before the History tap, like a user glancing at the
/// feed first.
const Duration _idleOnFeed = Duration(milliseconds: 1500);

const List<String> _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// The newest of [buildSessions]: History lists it first.
bool _listOnScreen() => find.text('Workout 0').evaluate().isNotEmpty;

bool _calendarOnScreen() => find.byType(HistoryCalendar).evaluate().isNotEmpty;

class _Samples {
  final wallUs = <int>[];
  final frames = <int>[];
  final heaviestUs = <int>[];

  void add(FrameProbe probe, FrameTimingLog log) {
    wallUs.add(probe.hitMicros!);
    frames.add(probe.frames);
    final builds = log.buildMicros(probe.frameNumbers);
    heaviestUs.add(builds.isEmpty ? 0 : builds.reduce((a, b) => a > b ? a : b));
  }

  static String _stat(List<int> v, double Function(int) f, String unit) {
    final s = [...v]..sort();
    final med = f(s[s.length ~/ 2]);
    final p95 = f(s[((s.length - 1) * 95) ~/ 100]);
    return 'median=${med.toStringAsFixed(2)}$unit p95=${p95.toStringAsFixed(2)}$unit';
  }

  String line(String name, int n) =>
      'BENCH history_shell | $name | sessions=$n | runs=${wallUs.length} | '
      'tap->visible ${_stat(wallUs, (u) => u / 1000, 'ms')} | '
      'frames ${_stat(frames, (f) => f.toDouble(), '')} | '
      'heaviest frame ${_stat(heaviestUs, (u) => u / 1000, 'ms')}';
}

Future<void> _measure(
  FrameTimingLog log,
  _Samples samples,
  bool Function() visible,
  Future<void> Function() interact,
) async {
  // Let any frame still in flight finish so it is not counted.
  await Future<void>.delayed(const Duration(milliseconds: 50));
  final probe = FrameProbe.start(visible);
  await interact();
  await probe.done.timeout(const Duration(seconds: 20));
  // FrameTimings arrive in batches; give the engine time to report them.
  await Future<void>.delayed(const Duration(milliseconds: 400));
  samples.add(probe, log);
}

Future<void> main() async {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('history shell benchmark', (tester) async {
    HydratedBloc.storage = InMemoryStorage();
    final dir = Directory.systemTemp.createTempSync('bench_history_shell');
    final isar = await Isar.open(
      [ExerciseSchema, GymSchema, WorkoutSplitSchema, WorkoutSessionSchema],
      directory: dir.path,
      name: 'bench_history_shell',
    );
    final repo = TrackerRepository(isar);
    final log = FrameTimingLog();

    var mount = 0;
    Future<void> pumpFreshApp() async {
      mount++;
      await tester.pumpWidget(
        KeyedSubtree(
          key: ValueKey('app$mount'),
          child: RepositoryScope(
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
        ),
      );
      await tester.pump();
    }

    void selectTab(int index) => tester
        .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
        .onChange!(index);

    for (final n in sessionCounts) {
      await isar.writeTxn(() async {
        await isar.workoutSessions.clear();
        await isar.workoutSessions.putAll(buildSessions(n));
      });

      // S1: first History open after a moment on the Feed. S0 records the
      // heaviest frame the Feed rendered during that idle time.
      final firstOpen = _Samples();
      final feedIdle = <int>[];
      for (var i = 0; i < _iterations; i++) {
        await pumpFreshApp();
        final idleFrom = PlatformDispatcher.instance.frameData.frameNumber + 1;
        await Future<void>.delayed(_idleOnFeed);
        feedIdle.add(log.maxBuildBetween(idleFrom, 1 << 62));
        await _measure(log, firstOpen, _listOnScreen, () async {
          selectTab(1);
        });
      }
      final idle = [...feedIdle]..sort();
      print(
        'BENCH history_shell | S0 feed idle before History tap | sessions=$n | '
        'heaviest frame median=${(idle[idle.length ~/ 2] / 1000).toStringAsFixed(2)}ms '
        'max=${(idle.last / 1000).toStringAsFixed(2)}ms',
      );
      print(firstOpen.line('S1 first open after 1.5s on Feed', n));

      // S2: History tapped right after launch (nothing had time to warm up).
      final immediate = _Samples();
      for (var i = 0; i < _iterations; i++) {
        await pumpFreshApp();
        await _measure(log, immediate, _listOnScreen, () async {
          selectTab(1);
        });
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      print(immediate.line('S2 first open right after launch', n));

      // S3/S4: the calendar sheet opening, and a jump to a day from it.
      final openSheet = _Samples();
      final jump = _Samples();
      final rootNavigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      for (var i = 0; i < _iterations; i++) {
        final calendar = tester.getCenter(fButtonByTooltip('Calendar'));
        await _measure(log, openSheet, _calendarOnScreen, () async {
          await tester.tapAt(calendar);
        });
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (i.isOdd) {
          rootNavigator.pop();
          await Future<void>.delayed(const Duration(milliseconds: 400));
          continue;
        }
        final day = tester.getCenter(dayCells().at(i ~/ 2));
        await _measure(log, jump, () => !_calendarOnScreen(), () async {
          await tester.tapAt(day);
        });
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      print(openSheet.line('S3 open the calendar sheet', n));
      print(jump.line('S4 jump to a workout day', n));

      // S5: month navigation, in the sheet.
      await tester.tap(fButtonByTooltip('Calendar'));
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final monthNav = _Samples();
      var shown = DateTime(DateTime.now().year, DateTime.now().month);
      for (var i = 0; i < _iterations; i++) {
        final delta = i.isEven ? -1 : 1;
        final target = DateTime(shown.year, shown.month + delta);
        final label = '${_months[target.month - 1]} ${target.year}';
        await _measure(
          log,
          monthNav,
          () => find.text(label).evaluate().isNotEmpty,
          () async => tester.fling(
            find.byType(PageView),
            Offset(delta < 0 ? 400 : -400, 0),
            1000,
          ),
        );
        shown = target;
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      print(monthNav.line('S5 month change', n));
      rootNavigator.pop();
      await Future<void>.delayed(const Duration(milliseconds: 400));

      // Back to the top of the list, where a new session lands.
      tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(HistoryPage),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .jumpTo(0);
      final now = DateTime.now();

      // S7: a session saved while History is on screen (e.g. after editing
      // one), until it shows at the top of the list.
      final write = _Samples();
      for (var i = 0; i < _iterations; i++) {
        final title = 'Bench write $i';
        final start = DateTime(now.year, now.month, now.day, 12, i);
        await _measure(
          log,
          write,
          () => find.text(title).evaluate().isNotEmpty,
          () => repo.sessions.put(
            WorkoutSession(
              title: title,
              startTime: start,
              endTime: start.add(const Duration(minutes: 30)),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      print(write.line('S7 session saved while History open', n));
    }

    log.dispose();
    await tester.pumpWidget(const SizedBox());
    await isar.close(deleteFromDisk: true);
  }, timeout: const Timeout(Duration(minutes: 20)));
}
