// Keyboard-in-sheet benchmark: the real app (MyApp + Isar + the sweep
// fixtures), Gyms pushed from the Feed tab, the Edit gym sheet open, then the
// device's own soft keyboard opened on the name field and closed again.
// Engine FrameTimings, profile mode, on an Android device or emulator. Run
// from tracker/:
//   flutter drive --profile -d <device> --driver=benchmark/drive/history_calendar_driver.dart --target=benchmark/keyboard_sheet_device_test.dart
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:integration_test/integration_test.dart';
import 'package:isar_community/isar.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/data/services/seed.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tracker/main.dart';
import 'package:tracker/routing/home_page.dart';
import 'package:tracker/ui/core/themes/material_theme_bridge.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/feed/widgets/feed_page.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/settings/widgets/gyms_page.dart';
import 'package:tracker/ui/splits/view_models/split_drafts_cubit.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

import '../testing/fakes/in_memory_storage.dart';
import '../testing/test_fixtures.dart';

const int _runs = 8;

/// Records one traced open and close, with an event per widget build and
/// layout, into the driver's response data (`timeline`).
const bool _trace = bool.fromEnvironment('BENCH_TRACE');

/// `perframe` swaps MyApp for a copy that, like the app before
/// `KeyboardReveal`, builds a new FTheme on every keyboard frame.
const String _app = String.fromEnvironment('BENCH_APP', defaultValue: 'real');

/// MyApp with the per-inset FTheme copy the app made before `KeyboardReveal`.
class _PerFrameThemeApp extends StatelessWidget {
  const _PerFrameThemeApp();

  @override
  Widget build(BuildContext context) {
    final light = strengthenNavLabels(FTheme.neutral.light.touch);
    final dark = strengthenNavLabels(FTheme.neutral.dark.touch);
    return MaterialApp(
      supportedLocales: FLocalizations.supportedLocales,
      localizationsDelegates: const [
        ...FLocalizations.localizationsDelegates,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const FScaffold(
        resizeToAvoidBottomInset: false,
        childPad: false,
        child: HomePage(),
      ),
      theme: light.toCustomMaterialTheme(),
      darkTheme: dark.toCustomMaterialTheme(),
      builder: (context, child) {
        final theme = Theme.brightnessOf(context) == Brightness.light
            ? light
            : dark;
        final inset = MediaQuery.viewInsetsOf(context).bottom;
        return FTheme(
          data: inset <= 0
              ? theme
              : theme.copyWith(
                  textFieldStyles: theme.textFieldStyles.apply([
                    .all(
                      .delta(
                        scrollPadding: EdgeInsetsDelta.add(bottom: inset + 40),
                      ),
                    ),
                  ]),
                ),
          child: FToaster(child: FTooltipGroup(child: child!)),
        );
      },
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
    );
  }
}

/// The frame budget aimed for: 120 Hz.
const int _budgetUs = 8000;

/// Every reported FrameTiming, by frame number.
class _Timings {
  _Timings() {
    SchedulerBinding.instance.addTimingsCallback(_on);
  }
  final Map<int, FrameTiming> byFrame = {};
  void _on(List<FrameTiming> t) {
    for (final f in t) {
      byFrame[f.frameNumber] = f;
    }
  }

  void dispose() => SchedulerBinding.instance.removeTimingsCallback(_on);
}

class _Phase {
  final ui = <int>[];
  final raster = <int>[];
  final frames = <int>[];
  var overBudget = 0;
  var uiOverBudget = 0;

  /// Where each UI frame over budget fell: frame index in its run, and ms.
  final slowUi = <String>[];

  static String _ms(int us) => (us / 1000).toStringAsFixed(2);

  static String _stats(List<int> v) {
    final s = [...v]..sort();
    if (s.isEmpty) return 'none';
    return 'median=${_ms(s[s.length ~/ 2])}ms '
        'p90=${_ms(s[((s.length - 1) * 90) ~/ 100])}ms '
        'max=${_ms(s.last)}ms';
  }

  String line(String name) =>
      'BENCH keyboard | $name | runs=${frames.length} '
      'frames/run=${frames.isEmpty ? 0 : ([...frames]..sort())[frames.length ~/ 2]} | '
      'ui ${_stats(ui)} | raster ${_stats(raster)} | '
      'frames over ${_ms(_budgetUs)}ms: ui=$uiOverBudget '
      'ui or raster=$overBudget of ${ui.length} | slow ui at ${slowUi.join(' ')}';
}

Future<void> main() async {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('keyboard in a bottom sheet', (tester) async {
    HydratedBloc.storage = InMemoryStorage();
    final dir = Directory.systemTemp.createTempSync('bench_keyboard');
    final isar = await Isar.open(
      [ExerciseSchema, GymSchema, WorkoutSplitSchema, WorkoutSessionSchema],
      directory: dir.path,
      name: 'bench_keyboard',
    );
    final repo = TrackerRepository(isar);
    await seedExercisesIfNeeded(repo);
    await seedSweepFixtures(repo);
    final timings = _Timings();

    await tester.pumpWidget(
      RepositoryProvider<TrackerRepository>.value(
        value: repo,
        child: RepositoryScope(
          repository: repo,
          child: MultiBlocProvider(
            providers: [
              BlocProvider<WorkoutCubit>(
                create: (_) => WorkoutCubit(repository: repo),
                lazy: false,
              ),
              BlocProvider<SettingsCubit>(
                create: (_) => SettingsCubit(),
                lazy: false,
              ),
              BlocProvider<SplitDraftsCubit>(
                create: (_) => SplitDraftsCubit(repository: repo),
                lazy: false,
              ),
            ],
            child: _app == 'perframe'
                ? const _PerFrameThemeApp()
                : const MyApp(),
          ),
        ),
      ),
    );
    // Past the History offstage prebuild (~1 s after launch).
    await Future<void>.delayed(const Duration(milliseconds: 2500));

    final feedContext = tester.element(
      find.byType(FeedPage, skipOffstage: false),
    );
    pushTo<void>(feedContext, const GymsPage());
    await Future<void>.delayed(const Duration(milliseconds: 800));
    await tester.tap(find.text('Iron Temple'));
    await Future<void>.delayed(const Duration(milliseconds: 800));
    final nameField = find.widgetWithText(FTextField, 'Gym name');
    expect(nameField, findsOneWidget);

    Future<void> measure(_Phase into, Future<void> Function() act) async {
      final from = PlatformDispatcher.instance.frameData.frameNumber + 1;
      await act();
      // The IME animates for ~300 ms on Android.
      await Future<void>.delayed(const Duration(milliseconds: 900));
      final to = PlatformDispatcher.instance.frameData.frameNumber;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      var frames = 0;
      for (var f = from; f <= to; f++) {
        final t = timings.byFrame[f];
        if (t == null) continue;
        frames++;
        final ui = t.buildDuration.inMicroseconds;
        final raster = t.rasterDuration.inMicroseconds;
        into.ui.add(ui);
        into.raster.add(raster);
        if (ui > _budgetUs || raster > _budgetUs) into.overBudget++;
        if (ui > _budgetUs) {
          into.uiOverBudget++;
          into.slowUi.add('#${frames - 1}:${_Phase._ms(ui)}');
        }
      }
      into.frames.add(frames);
    }

    Future<void> openKeyboard() async {
      await tester.tap(nameField);
    }

    Future<void> closeKeyboard() async {
      FocusManager.instance.primaryFocus?.unfocus();
    }

    // Warm-up: the first open in a process also starts the IME.
    await measure(_Phase(), openKeyboard);
    final inset = tester.view.viewInsets.bottom / tester.view.devicePixelRatio;
    await measure(_Phase(), closeKeyboard);

    final open = _Phase();
    final close = _Phase();
    for (var i = 0; i < _runs; i++) {
      await measure(open, openKeyboard);
      await measure(close, closeKeyboard);
    }
    if (_trace) {
      debugProfileBuildsEnabled = true;
      debugProfileLayoutsEnabled = true;
      await binding.traceAction(() async {
        await measure(_Phase(), openKeyboard);
        await measure(_Phase(), closeKeyboard);
      }, reportKey: 'timeline');
      debugProfileBuildsEnabled = false;
      debugProfileLayoutsEnabled = false;
    }
    print(
      'BENCH keyboard | app=$_app | keyboard height=${inset.toStringAsFixed(0)}dp',
    );
    print(open.line('OPEN keyboard in Edit gym sheet'));
    print(close.line('CLOSE keyboard in Edit gym sheet'));

    timings.dispose();
    await tester.pumpWidget(const SizedBox());
    await isar.close(deleteFromDisk: true);
  });
}
