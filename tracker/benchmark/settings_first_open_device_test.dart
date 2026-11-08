// Settings audit benchmark: the real app (MyApp + Isar), Settings pushed from
// the Feed tab. Engine FrameTimings, profile mode. Run from tracker/:
//   flutter drive --profile -d windows --driver=benchmark/drive/history_calendar_driver.dart --target=benchmark/settings_first_open_device_test.dart --dart-define=BENCH_FIRST=settings
// BENCH_FIRST picks the variant opened first in the process (the cold open).
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:integration_test/integration_test.dart';
import 'package:isar_community/isar.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/main.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tracker/routing/home_page.dart';
import 'package:tracker/ui/core/themes/material_theme_bridge.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/core/ui/keyboard_inset.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/feed/widgets/feed_page.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/settings/widgets/gyms_page.dart';
import 'package:tracker/ui/settings/widgets/settings_page.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

import '../testing/fakes/in_memory_storage.dart';
import '../testing/frame_probe.dart';
import 'calendar_benchmark_support.dart';

const String _first = String.fromEnvironment(
  'BENCH_FIRST',
  defaultValue: 'settings',
);
const int _iterations = 12;

/// Stop after the cold open (one cold sample per process).
const bool _coldOnly = bool.fromEnvironment('BENCH_COLD_ONLY');

/// Build SettingsPage offstage once during the launch idle, then remove it,
/// before the cold open (what a HomePage-style prebuild would do).
const bool _prewarm = bool.fromEnvironment('BENCH_PREWARM');

/// `noreveal` swaps MyApp for a copy without the per-inset FTheme copy.
const String _app = String.fromEnvironment('BENCH_APP', defaultValue: 'real');

const _probeKey = ValueKey('bench-probe');

Widget _row(BuildContext context, String title, Widget suffix) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  child: FCard(
    child: FItem(
      prefix: Icon(FLucideIcons.scale, color: context.theme.colors.primary),
      title: Text(title),
      subtitle: Text(
        'Subtitle for $title',
        style: context.theme.typography.body.xs.copyWith(
          color: context.theme.colors.mutedForeground,
        ),
      ),
      suffix: suffix,
    ),
  ),
);

Widget _page(List<Widget> Function(BuildContext) rows) => Builder(
  builder: (context) => CustomScrollView(
    slivers: [
      CustomAppBar(context, title: 'Bench'),
      SliverList(delegate: SliverChildListDelegate(rows(context))),
    ],
  ),
);

Widget _select() => SizedBox(
  width: 120,
  child: FSelect<int>(
    items: const {'kg': 0, 'lb': 1},
    control: FSelectControl<int>.lifted(value: 0, onChange: (_) {}),
  ),
);

Widget _field() => SizedBox(
  width: 120,
  child: FTextField(
    control: FTextFieldControl.managed(
      initial: const TextEditingValue(text: '10'),
    ),
    keyboardType: TextInputType.number,
    label: const Text('Reps'),
  ),
);

Widget _menuSelect() => FPopoverMenu.tiles(
  menu: [
    .group(
      children: [
        .tile(title: const Text('kg'), onPress: () {}),
        .tile(title: const Text('lb'), onPress: () {}),
      ],
    ),
  ],
  builder: (_, controller, _) => FButton(
    variant: .outline,
    onPress: controller.toggle,
    suffix: const Icon(FLucideIcons.chevronDown),
    child: const Text('kg'),
  ),
);

final Map<String, Widget Function()> _variants = {
  'settings': () => const SettingsPage(),
  'empty': () => _page((_) => const []),
  'rows8_plain': () => _page(
    (c) => [for (var i = 0; i < 8; i++) _row(c, 'Row $i', const Text('value'))],
  ),
  'rows8_3select': () => _page(
    (c) => [
      for (var i = 0; i < 3; i++) _row(c, 'Select $i', _select()),
      for (var i = 0; i < 5; i++) _row(c, 'Row $i', const Text('value')),
    ],
  ),
  'rows8_3select_intrinsic': () => _page(
    (c) => [
      for (var i = 0; i < 3; i++)
        _row(
          c,
          'Select $i',
          IntrinsicWidth(
            child: FSelect<int>(
              items: const {'Rep range': 0, 'Fixed reps': 1},
              control: FSelectControl<int>.lifted(value: 0, onChange: (_) {}),
            ),
          ),
        ),
      for (var i = 0; i < 5; i++) _row(c, 'Row $i', const Text('value')),
    ],
  ),
  'rows8_3menu': () => _page(
    (c) => [
      for (var i = 0; i < 3; i++) _row(c, 'Menu $i', _menuSelect()),
      for (var i = 0; i < 5; i++) _row(c, 'Row $i', const Text('value')),
    ],
  ),
  'rows8_3field': () => _page(
    (c) => [
      for (var i = 0; i < 3; i++) _row(c, 'Field $i', _field()),
      for (var i = 0; i < 5; i++) _row(c, 'Row $i', const Text('value')),
    ],
  ),
  'rows8_2switch': () => _page(
    (c) => [
      for (var i = 0; i < 2; i++)
        _row(c, 'Switch $i', FSwitch(value: true, onChange: (_) {})),
      for (var i = 0; i < 6; i++) _row(c, 'Row $i', const Text('value')),
    ],
  ),
};

class _Open {
  final firstUi = <int>[];
  final firstRaster = <int>[];
  final maxUi = <int>[];
  final maxRaster = <int>[];
  final maxLatency = <int>[];
  final frames = <int>[];

  static String _med(List<int> v) {
    final s = [...v]..sort();
    return (s[s.length ~/ 2] / 1000).toStringAsFixed(2);
  }

  static String _p95(List<int> v) {
    final s = [...v]..sort();
    return (s[((s.length - 1) * 95) ~/ 100] / 1000).toStringAsFixed(2);
  }

  String line(String name) =>
      'BENCH settings | $name | runs=${firstUi.length} | '
      'first frame ui median=${_med(firstUi)}ms p95=${_p95(firstUi)}ms '
      'raster median=${_med(firstRaster)}ms | '
      'transition max ui median=${_med(maxUi)}ms '
      'max raster median=${_med(maxRaster)}ms '
      'max vsync+ui median=${_med(maxLatency)}ms | '
      'frames in 300ms median=${frames.isEmpty ? 0 : ([...frames]..sort())[frames.length ~/ 2]}';
}

/// MyApp without `keyboardAwareFieldReveal`: the FTheme never changes with
/// the keyboard inset.
class _NoRevealApp extends StatelessWidget {
  const _NoRevealApp();

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
      builder: (context, child) => FTheme(
        data: Theme.brightnessOf(context) == Brightness.light ? light : dark,
        child: FToaster(child: FTooltipGroup(child: child!)),
      ),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
    );
  }
}

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

Future<void> main() async {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('settings audit benchmark', (tester) async {
    HydratedBloc.storage = InMemoryStorage();
    final dir = Directory.systemTemp.createTempSync('bench_settings');
    final isar = await Isar.open(
      [ExerciseSchema, GymSchema, WorkoutSplitSchema, WorkoutSessionSchema],
      directory: dir.path,
      name: 'bench_settings',
    );
    final repo = TrackerRepository(isar);
    final timings = _Timings();

    await tester.pumpWidget(
      RepositoryScope(
        repository: repo,
        child: MultiBlocProvider(
          providers: [
            BlocProvider<WorkoutCubit>(
              create: (_) => WorkoutCubit(repository: repo),
            ),
            BlocProvider<SettingsCubit>(create: (_) => SettingsCubit()),
          ],
          child: _app == 'noreveal' ? const _NoRevealApp() : const MyApp(),
        ),
      ),
    );
    // Past the History offstage prebuild (~1 s after launch).
    await Future<void>.delayed(const Duration(milliseconds: 2500));

    BuildContext feedContext() =>
        tester.element(find.byType(FeedPage, skipOffstage: false));

    Future<void> open(String name, _Open into) async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final probe = FrameProbe.start(
        () => find.byKey(_probeKey).evaluate().isNotEmpty,
      );
      final fromFrame = PlatformDispatcher.instance.frameData.frameNumber + 1;
      pushTo<void>(
        feedContext(),
        KeyedSubtree(key: _probeKey, child: _variants[name]!()),
      );
      await probe.done.timeout(const Duration(seconds: 20));
      // Slide transition is 250 ms.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final toFrame = PlatformDispatcher.instance.frameData.frameNumber;
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final hit = timings.byFrame[probe.frameNumbers.last];
      into.firstUi.add(hit?.buildDuration.inMicroseconds ?? -1);
      into.firstRaster.add(hit?.rasterDuration.inMicroseconds ?? -1);
      var maxUi = 0, maxRaster = 0, maxLatency = 0, frames = 0;
      for (var f = fromFrame; f <= toFrame; f++) {
        final t = timings.byFrame[f];
        if (t == null) continue;
        frames++;
        final ui = t.buildDuration.inMicroseconds;
        final raster = t.rasterDuration.inMicroseconds;
        final latency = t.vsyncOverhead.inMicroseconds + ui;
        if (ui > maxUi) maxUi = ui;
        if (raster > maxRaster) maxRaster = raster;
        if (latency > maxLatency) maxLatency = latency;
      }
      into.maxUi.add(maxUi);
      into.maxRaster.add(maxRaster);
      into.maxLatency.add(maxLatency);
      into.frames.add(frames);
      Navigator.of(feedContext()).pop();
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }

    if (_prewarm) {
      final entry = OverlayEntry(
        builder: (_) => const Offstage(child: SettingsPage()),
      );
      Navigator.of(feedContext()).overlay!.insert(entry);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      entry.remove();
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    // C: the cold open, first build of this variant's widgets in the process.
    final cold = _Open();
    await open(_first, cold);
    print(
      cold.line(
        'COLD first open of "$_first" in process${_prewarm ? ' (prewarmed)' : ''}',
      ),
    );
    if (_coldOnly) {
      timings.dispose();
      await tester.pumpWidget(const SizedBox());
      await isar.close(deleteFromDisk: true);
      return;
    }

    // W: warm opens, interleaved so drift hits every variant alike.
    final warm = {for (final name in _variants.keys) name: _Open()};
    for (var i = 0; i < _iterations; i++) {
      for (final name in _variants.keys) {
        await open(name, warm[name]!);
      }
    }
    for (final entry in warm.entries) {
      print(entry.value.line('WARM ${entry.key}'));
    }

    // K: simulated soft keyboard opening over Settings (20 frames to 300 px),
    // then closing. Every inset change rebuilds MyApp.builder's FTheme.
    pushTo<void>(feedContext(), const SettingsPage());
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final kbUi = <int>[];
    for (var run = 0; run < 3; run++) {
      for (final up in [true, false]) {
        final from = PlatformDispatcher.instance.frameData.frameNumber + 1;
        for (var s = 1; s <= 20; s++) {
          final v = 300.0 * (up ? s : 20 - s) / 20;
          tester.view.viewInsets = FakeViewPadding(bottom: v);
          await Future<void>.delayed(const Duration(milliseconds: 17));
        }
        await Future<void>.delayed(const Duration(milliseconds: 400));
        final to = PlatformDispatcher.instance.frameData.frameNumber;
        await Future<void>.delayed(const Duration(milliseconds: 300));
        for (var f = from; f <= to; f++) {
          final t = timings.byFrame[f];
          if (t != null) kbUi.add(t.buildDuration.inMicroseconds);
        }
      }
    }
    tester.view.resetViewInsets();
    kbUi.sort();
    print(
      'BENCH settings | KEYBOARD app=$_app inset animation over Settings | '
      'frames=${kbUi.length} | ui median=${(kbUi[kbUi.length ~/ 2] / 1000).toStringAsFixed(2)}ms '
      'p95=${(kbUi[((kbUi.length - 1) * 95) ~/ 100] / 1000).toStringAsFixed(2)}ms '
      'max=${(kbUi.last / 1000).toStringAsFixed(2)}ms',
    );

    // T: the theme work one inset change triggers, outside any frame.
    final theme = FTheme.neutral.light.touch;
    final revealUs = <int>[];
    final lerpUs = <int>[];
    final eqUs = <int>[];
    for (var i = 0; i < 200; i++) {
      final sw = Stopwatch()..start();
      final revealed = keyboardAwareFieldReveal(theme, 100.0 + i);
      sw.stop();
      revealUs.add(sw.elapsedMicroseconds);
      final sw2 = Stopwatch()..start();
      FThemeData.lerp(theme, revealed, 0.5);
      sw2.stop();
      lerpUs.add(sw2.elapsedMicroseconds);
      final sw3 = Stopwatch()..start();
      // ignore: unnecessary_statements
      theme == revealed;
      sw3.stop();
      eqUs.add(sw3.elapsedMicroseconds);
    }
    String med(List<int> v) => '${(([...v]..sort())[v.length ~/ 2])}us';
    print(
      'BENCH settings | THEME per inset change | keyboardAwareFieldReveal '
      '${med(revealUs)} | FThemeData.lerp ${med(lerpUs)} | == ${med(eqUs)}',
    );

    // S: one switch toggle (cubit emit; BlocBuilder rebuilds the whole page).
    final toggleUi = <int>[];
    final settingsCubit = tester
        .element(find.byType(SettingsPage))
        .read<SettingsCubit>();
    for (var i = 0; i < 20; i++) {
      final probe = FrameProbe.start(() => true);
      settingsCubit.setNotificationsEnabled(
        !settingsCubit.state.notificationsEnabled,
      );
      await probe.done.timeout(const Duration(seconds: 5));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final t = timings.byFrame[probe.frameNumbers.last];
      if (t != null) toggleUi.add(t.buildDuration.inMicroseconds);
    }
    print(
      'BENCH settings | TOGGLE notifications switch | '
      'ui median=${(([...toggleUi]..sort())[toggleUi.length ~/ 2] / 1000).toStringAsFixed(2)}ms',
    );

    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(feedContext()).pop();
    await Future<void>.delayed(const Duration(milliseconds: 500));

    // G: GymsPage open, which loads every session to decide canEstimate.
    for (final n in [0, 500, 2000]) {
      await isar.writeTxn(() async {
        await isar.workoutSessions.clear();
        await isar.workoutSessions.putAll(buildSessions(n));
      });
      final getAllUs = <int>[];
      final countUs = <int>[];
      for (var i = 0; i < 5; i++) {
        final sw = Stopwatch()..start();
        await repo.sessions.getAll();
        sw.stop();
        getAllUs.add(sw.elapsedMicroseconds);
        final sw2 = Stopwatch()..start();
        await isar.workoutSessions.count();
        sw2.stop();
        countUs.add(sw2.elapsedMicroseconds);
      }
      final gyms = _Open();
      for (var i = 0; i < 6; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        final probe = FrameProbe.start(
          () => find.byType(GymsPage).evaluate().isNotEmpty,
        );
        final fromFrame = PlatformDispatcher.instance.frameData.frameNumber + 1;
        pushTo<void>(feedContext(), const GymsPage());
        await probe.done.timeout(const Duration(seconds: 20));
        await Future<void>.delayed(const Duration(milliseconds: 600));
        final toFrame = PlatformDispatcher.instance.frameData.frameNumber;
        await Future<void>.delayed(const Duration(milliseconds: 400));
        var maxUi = 0, maxLatency = 0, frames = 0;
        for (var f = fromFrame; f <= toFrame; f++) {
          final t = timings.byFrame[f];
          if (t == null) continue;
          frames++;
          final ui = t.buildDuration.inMicroseconds;
          final latency = t.vsyncOverhead.inMicroseconds + ui;
          if (ui > maxUi) maxUi = ui;
          if (latency > maxLatency) maxLatency = latency;
        }
        final hit = timings.byFrame[probe.frameNumbers.last];
        gyms.firstUi.add(hit?.buildDuration.inMicroseconds ?? -1);
        gyms.firstRaster.add(hit?.rasterDuration.inMicroseconds ?? -1);
        gyms.maxUi.add(maxUi);
        gyms.maxRaster.add(0);
        gyms.maxLatency.add(maxLatency);
        gyms.frames.add(frames);
        Navigator.of(feedContext()).pop();
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
      print(
        'BENCH settings | GYMS sessions=$n | sessions.getAll median=${med(getAllUs)} '
        'count median=${med(countUs)}',
      );
      print(gyms.line('GYMS open sessions=$n'));
    }

    timings.dispose();
    await tester.pumpWidget(const SizedBox());
    await isar.close(deleteFromDisk: true);
  }, timeout: const Timeout(Duration(minutes: 20)));
}
