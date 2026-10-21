// Tier 2 capture test for the system-back exit guard (see
// docs/CAPTURING_MEDIA.md). Boots the real app window on Windows with
// throwaway data (in-memory HydratedBloc storage + temp Isar, never the
// user's real app data) and drives the exact bug scenario:
//
// 1. Open the split editor from the Editor tab and type a title (dirty).
// 2. Send a system back: the "Discard changes?" dialog appears.
// 3. Send a second system back while the dialog is up: with the guard this
//    press is swallowed and the dialog stays; without it the dialog was
//    dismissed behind the user's back (the unguarded path that can fall
//    through to SystemNavigator.pop and kill the app).
//
// Run via the repo-root helper:
//
//   pwsh ./capture-app-media.ps1 -Mode video -Seconds 36 -Test tracker/integration_test/capture_back_guard_test.dart
//
// CAPTURE_EXPECT selects which behavior the run asserts: 'unguarded' for the
// pre-fix before capture, 'guarded' with the fix (default: no assertion, the
// recorded behavior is printed instead).
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/data/services/seed.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/main.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';
import 'package:window_size/window_size.dart';

import '../testing/fakes/in_memory_storage.dart';
import '../testing/test_helpers.dart';

Future<void> main() async {
  // Live binding (like split_discard_demo_test.dart), not the integration
  // test binding: its fake-async zone collapses Future.delayed pauses, which
  // makes the walkthrough invisible in a real-time recording. Live runs the
  // body in real async so the on-screen pacing matches the video.
  final binding = LiveTestWidgetsFlutterBinding.ensureInitialized();
  // Fully live frames so what the window shows matches what the test pumps.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(initIsarCore);

  testWidgets('capture: system-back exit guard around the discard dialog', (
    tester,
  ) async {
    // This test bypasses main() (throwaway data below), so it must set the
    // desktop window title itself: capture-app-media.ps1 locates the window
    // by the title 'Tracker' (the pre-Dart caption is lowercase 'tracker'
    // from windows/runner/main.cpp).
    if (Platform.isWindows) setWindowTitle('Tracker');

    HydratedBloc.storage = InMemoryStorage();
    final isar = await openTestIsar([
      ExerciseSchema,
      GymSchema,
      WorkoutSplitSchema,
      WorkoutSessionSchema,
    ], name: 'isar_capture_back_guard');
    final repo = TrackerRepository(isar);
    await seedExercisesIfNeeded(repo);
    final cubit = WorkoutCubit(repository: repo);

    await tester.pumpWidget(
      RepositoryScope(
        repository: repo,
        child: MultiBlocProvider(
          providers: [
            BlocProvider<WorkoutCubit>.value(value: cubit),
            BlocProvider<SettingsCubit>(create: (_) => SettingsCubit()),
          ],
          child: const MyApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Watchable pacing: the script records the window from boot, so hold
    // each state long enough to follow in the video.
    Future<void> pause([int ms = 1200]) async {
      await Future<void>.delayed(Duration(milliseconds: ms));
      await tester.pump();
    }

    // Simulates a system back exactly the way the engine delivers it: the
    // framework-side popRoute handling (WidgetsBinding.handlePopRoute).
    Future<void> systemBack() async {
      await WidgetsBinding.instance.handlePopRoute();
      await tester.pumpAndSettle();
    }

    // ---- drive the UI -----------------------------------------------------
    tester
        .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
        .onChange!(3);
    await tester.pumpAndSettle();
    await pause();

    await tester.tap(find.text('New Split'));
    await tester.pumpAndSettle();
    await pause();

    // Make the editor dirty so its PopScope intercepts the next back press.
    await tester.enterText(find.byType(FTextField).first, 'Push day');
    await tester.pumpAndSettle();
    await pause();

    // Back #1: the split editor shows the discard confirmation dialog.
    print('CAPTURE: back #1 - discard dialog should appear');
    await systemBack();
    expect(find.text('Discard changes?'), findsOneWidget);
    await pause(2500);

    // Back #2 while the dialog is up: with the dialog-aware exit guard this
    // press is swallowed and the dialog stays on screen; without it the
    // dialog was dismissed behind the user's back (and that unguarded path
    // is the one that can fall through to SystemNavigator.pop).
    print('CAPTURE: back #2 while the discard dialog is up');
    await systemBack();
    final dialogStillUp = tester.any(find.text('Discard changes?'));
    print('CAPTURE: dialog still up after back #2: $dialogStillUp');
    switch (Platform.environment['CAPTURE_EXPECT']) {
      case 'guarded':
        expect(
          dialogStillUp,
          isTrue,
          reason: 'the pending dialog must survive the second back press',
        );
      case 'unguarded':
        expect(
          dialogStillUp,
          isFalse,
          reason: 'pre-fix: the second back dismissed the pending dialog',
        );
    }
    await pause(3000);
    // ----------------------------------------------------------------------

    // The script captures the window externally. Keep the window on screen
    // until it signals "capture finished" by creating
    // build/captures/.capture-done (it deletes the file at the start of each
    // run). Cap the wait so a bare `flutter test` run still terminates.
    const doneFile = 'build/captures/.capture-done';
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (!File(doneFile).existsSync() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  });
}
