// Tier 2 capture: agent-driven video walkthrough of every app page.
// Boots the real Windows app window with throwaway data (in-memory HydratedBloc
// storage + temp Isar, never the user's real app data), then walks:
//
//   Feed -> Settings -> Gyms -> Progression -> Session detail -> Session edit
//   -> History (list + calendar + day page) -> Workout idle -> Editor
//   -> SplitDayPage -> start workout (gym picker sheet) -> in-progress + log a
//   set -> end workout dialog -> SplitEditorPage -> SplitDayEditorPage
//   -> ExercisePickerPage -> New Split -> Exercises -> Exercise detail
//   -> New exercise -> Feed (with graph editor sheet).
//
// Run with (see docs/CAPTURING_MEDIA.md):
//
//   pwsh ./capture-app-media.ps1 -Mode video -Seconds 75 -Test tracker/integration_test/capture_full_walkthrough_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/data/services/seed.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/graph_config.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/main.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';
import 'package:window_size/window_size.dart';

import '../testing/fakes/in_memory_storage.dart';
import '../testing/test_fixtures.dart';
import '../testing/test_helpers.dart';

Future<void> main() async {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Fully live frames so what the window shows matches what the test pumps.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(initIsarCore);

  testWidgets('capture: full walkthrough of every page', (tester) async {
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
    ], name: 'isar_capture_walkthrough');
    final repo = TrackerRepository(isar);
    await seedExercisesIfNeeded(repo);
    await seedSweepFixtures(repo);
    final cubit = WorkoutCubit(repository: repo);

    await tester.pumpWidget(
      RepositoryScope(
        repository: repo,
        child: MultiBlocProvider(
          providers: [
            BlocProvider<WorkoutCubit>.value(value: cubit),
            BlocProvider<SettingsCubit>(
              create: (_) => SettingsCubit()
                ..addGraph(const GraphConfig(title: 'Strength - upper body')),
              lazy: false,
            ),
          ],
          child: const MyApp(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    // ---- drive the UI (edit only this section in copies) ----------------

    // Watchable pacing: real (non-fake-async) delay + a pump to flush the
    // frame queue after each step.
    Future<void> pause([int ms = 1400]) async {
      await Future<void>.delayed(Duration(milliseconds: ms));
      await tester.pump();
    }

    Future<void> afterTap() => tester.pump(const Duration(milliseconds: 400));

    /// Empty-safe finder check: pre-restricted finders (`.first`, `.at`)
    /// throw StateError when nothing matches; plain finders do not.
    bool has(Finder finder) {
      try {
        return tester.any(finder);
      } catch (_) {
        return false;
      }
    }

    void switchTab(int index) => tester
        .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
        .onChange!(index);

    Future<void> back() async {
      final chevron = find.byIcon(FLucideIcons.chevronLeft);
      if (tester.any(chevron)) {
        await tester.tap(chevron.first, warnIfMissed: false);
        await afterTap();
      }
    }

    /// Brings [finder] on screen if it lives inside a scrollable; never
    /// throws (pages without a scrollable are simply already visible).
    Future<void> show(Finder finder) async {
      try {
        await tester.ensureVisible(finder.first);
        await afterTap();
      } catch (_) {}
    }

    // 1) Feed: sessions, graph cards, Progression entry.
    await pause(2200);
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -400),
    );
    await afterTap();
    await pause(1000);

    // 2) Feed graph card menu -> graph editor sheet -> close.
    final kebab = find.byIcon(FLucideIcons.ellipsisVertical);
    if (tester.any(kebab)) {
      await show(kebab);
      await tester.tap(kebab.first, warnIfMissed: false);
      await afterTap();
      await pause(900);
      final editTile = find.text('Edit');
      if (tester.any(editTile)) {
        await tester.tap(editTile.first, warnIfMissed: false);
        await afterTap();
        await pause(1600);
        final close = find.byIcon(FLucideIcons.x);
        if (tester.any(close)) {
          await tester.tap(close.first, warnIfMissed: false);
          await afterTap();
        }
        await pause(700);
      }
    }

    // 3) Settings -> Gyms (expand + collapse a gym's menu).
    await tester.tap(find.text('Settings'), warnIfMissed: false);
    await afterTap();
    await pause(1500);
    await tester.tap(find.text('Gyms'), warnIfMissed: false);
    await afterTap();
    await pause(1400);
    final ironTemple = find.text('Iron Temple');
    if (tester.any(ironTemple)) {
      await tester.tap(ironTemple.first, warnIfMissed: false);
      await afterTap();
      await pause(1300);
      await tester.tap(ironTemple.first, warnIfMissed: false);
      await afterTap();
      await pause(700);
    }
    await back(); // Gyms -> Settings
    await pause(700);
    await back(); // Settings -> Feed
    await pause(700);

    // 4) Progression page.
    final progression = find.text('Progression');
    await show(progression);
    await tester.tap(progression.first, warnIfMissed: false);
    await afterTap();
    await pause(2000);
    await back();
    await pause(700);

    // 5) Session detail -> session edit.
    final pushCard = find.textContaining('Push Day');
    if (tester.any(pushCard)) {
      await show(pushCard);
      await tester.tap(pushCard.first, warnIfMissed: false);
      await afterTap();
      await pause(1800);
      final editAction = find.text('Edit');
      if (tester.any(editAction)) {
        await tester.tap(editAction.first, warnIfMissed: false);
        await afterTap();
        await pause(1500);
        await back(); // edit -> detail
        await pause(700);
      }
      await back(); // detail -> feed
      await pause(700);
    }

    // 6) History: list, calendar, calendar day page, back to list.
    switchTab(1);
    await pause(1800);
    final calendarToggle = find.text('Calendar');
    if (tester.any(calendarToggle)) {
      await tester.tap(calendarToggle.first, warnIfMissed: false);
      await afterTap();
      await pause(1500);
      final day21 = find.text('21');
      if (tester.any(day21)) {
        await tester.tap(day21.first, warnIfMissed: false);
        await afterTap();
        await pause(1600);
        await back(); // day page -> calendar
        await pause(700);
      }
      final listToggle = find.text('List');
      if (tester.any(listToggle)) {
        await tester.tap(listToggle.first, warnIfMissed: false);
        await afterTap();
        await pause(900);
      }
    }
    final pullTile = find.textContaining('Pull Day');
    if (tester.any(pullTile)) {
      await tester.tap(pullTile.first, warnIfMissed: false);
      await afterTap();
      await pause(1800);
      await back(); // detail -> history
      await pause(700);
    }

    // 7) Workout tab idle state.
    switchTab(2);
    await pause(1600);

    // 8) Editor tab -> split day page -> start plan workout.
    switchTab(3);
    await pause(1600);
    final pushDayRow = find.text('Push Day');
    if (tester.any(pushDayRow)) {
      await tester.tap(pushDayRow.first, warnIfMissed: false);
      await afterTap();
      await pause(1600);
    }
    final startThis = find.text('Start this workout');
    if (tester.any(startThis)) {
      await tester.tap(startThis.first, warnIfMissed: false);
      await afterTap();
      await pause(1300); // gym picker sheet
      final gymChoice = find.text('Iron Temple');
      if (tester.any(gymChoice)) {
        await tester.tap(gymChoice.first, warnIfMissed: false);
        await afterTap();
      }
      await pause(2000); // workout tab, in progress
    }

    // 9) Log a set on the in-progress workout. The add-set form sits at the
    // bottom of the page: scroll it into view first (off-screen list children
    // are not built, so the fields may not exist in the tree yet).
    for (var i = 0; i < 3 && !has(find.byType(FTextField)); i++) {
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -350),
      );
      await afterTap();
      await pause(400);
    }
    final fieldInputs = find.descendant(
      of: find.byType(FTextField),
      matching: find.byType(EditableText),
    );
    if (has(fieldInputs)) {
      await tester.enterText(fieldInputs.first, '100');
      await afterTap();
      await tester.enterText(fieldInputs.at(1), '8');
      await afterTap();
      final addSet = find.text('Add set');
      if (has(addSet)) {
        await tester.tap(addSet.first, warnIfMissed: false);
        await afterTap();
        await pause(1500);
      }
    }

    // 10) End the workout through the confirmation dialog.
    final endWorkout = find.text('End Workout');
    if (tester.any(endWorkout)) {
      await show(endWorkout);
      await tester.tap(endWorkout.first, warnIfMissed: false);
      await afterTap();
      await pause(1500); // confirmation dialog
      final endSave = find.text('End & save');
      if (tester.any(endSave)) {
        await tester.tap(endSave.first, warnIfMissed: false);
        await afterTap();
        await pause(2200); // session written to Isar
      }
    }

    // 11) Split editor -> split day editor -> exercise picker.
    switchTab(3); // back to the Editor tab (still shows SplitDayPage)
    await pause(900);
    switchTab(3); // re-tap pops the tab back to its root (EditorPage)
    await pause(900);
    final splitHeader = find.text('Push Pull Legs - Complete Program');
    if (tester.any(splitHeader)) {
      await tester.tap(splitHeader.first, warnIfMissed: false);
      await afterTap();
      await pause(1500); // split editor (edit)
      if (tester.any(pushDayRow)) {
        await tester.tap(pushDayRow.first, warnIfMissed: false);
        await afterTap();
        await pause(1500); // split day editor
      }
      final addExercise = find.text('Add');
      if (tester.any(addExercise)) {
        await tester.tap(addExercise.first, warnIfMissed: false);
        await afterTap();
        await pause(1200); // exercise picker
        final bench = find.text('Bench Press');
        if (tester.any(bench)) {
          await show(bench);
          await tester.tap(bench.first, warnIfMissed: false);
          await afterTap();
          await pause(1000); // back on day editor with the exercise added
        }
      }
      final done = find.text('Done');
      if (tester.any(done)) {
        await tester.tap(done.first, warnIfMissed: false);
        await afterTap();
        await pause(900); // back on split editor
      }
      await back(); // split editor -> Editor tab root
      await pause(700);
    }

    // 12) New split (blank editor).
    final newSplit = find.text('New Split');
    if (tester.any(newSplit)) {
      await tester.tap(newSplit.first, warnIfMissed: false);
      await afterTap();
      await pause(1600);
      await back();
      await pause(700);
    }

    // 13) Exercises: accordion -> exercise detail -> new exercise.
    switchTab(4);
    await pause(1600);
    if (!tester.any(find.text('Bench Press'))) {
      final chest = find.textContaining('Chest (');
      if (tester.any(chest)) {
        await tester.tap(chest.first, warnIfMissed: false);
        await afterTap();
        await pause(700);
      }
    }
    final benchItem = find.text('Bench Press');
    if (tester.any(benchItem)) {
      await show(benchItem);
      await tester.tap(benchItem.first, warnIfMissed: false);
      await afterTap();
      await pause(2000); // exercise detail with 1RM chart
      await back();
      await pause(700);
    }
    final newExercise = find.text('New');
    if (tester.any(newExercise)) {
      await tester.tap(newExercise.first, warnIfMissed: false);
      await afterTap();
      await pause(1500); // new exercise page
      await back();
      await pause(700);
    }

    // 14) Feed: now shows the session saved by the ended workout.
    switchTab(0);
    await pause(1800);
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
