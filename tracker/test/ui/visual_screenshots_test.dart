// Visual screenshot sweep: renders every app page, dialog and sheet at the
// window sizes a Windows desktop session can hit and saves PNG captures to
// `build/test_screenshots/` (plus a manifest.json index) so layouts can be
// inspected visually — overflow, clipped text, misalignment, tofu glyphs.
//
// This is an inspection corpus, NOT baseline goldens (no comparison, files are
// disposable). The sweep also doubles as a hardened layout-overflow regression
// test: render exceptions are collected per page (with a `_FAIL` capture of
// the offending screen) and fail the sweep at the end.
// ignore_for_file: avoid_print

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:isar_community/isar.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/data/services/seed.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/graph_config.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/main.dart';
import 'package:tracker/ui/analytics/widgets/graph_editor.dart';
import 'package:tracker/ui/analytics/widgets/progression_page.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/exercises/widgets/exercise_detail_page.dart';
import 'package:tracker/ui/exercises/widgets/new_exercise_page.dart';
import 'package:tracker/ui/feed/widgets/feed_page.dart';
import 'package:tracker/ui/history/widgets/session_detail_page.dart';
import 'package:tracker/ui/history/widgets/session_edit_page.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/settings/widgets/gyms_page.dart';
import 'package:tracker/ui/settings/widgets/settings_page.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';
import 'package:tracker/ui/workout/widgets/exercise_picker_page.dart';
import 'package:tracker/ui/workout/widgets/gym_picker.dart';
import 'package:tracker/ui/workout/widgets/new_split_page.dart';
import 'package:tracker/ui/workout/widgets/split_day_editor_page.dart';
import 'package:tracker/ui/workout/widgets/split_day_page.dart';
import 'package:tracker/ui/workout/widgets/workout_page.dart';

import '../../testing/fakes/in_memory_storage.dart';
import '../../testing/screenshot_helpers.dart';
import '../../testing/test_fixtures.dart';
import '../../testing/test_fonts.dart';
import '../../testing/test_helpers.dart';

const _sizes = <(String, double, double)>[
  ('320x568-min', 320, 568),
  ('800x600-small', 800, 600),
  ('1280x720-default', 1280, 720),
];

void main() {
  setUpAll(initIsarCore);

  for (final (label, width, height) in _sizes) {
    testWidgets('capture screens at $label', (tester) async {
      await tester.runAsync(loadTestFonts);
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final recorder = ScreenshotRecorder(tester);
      recorder.beginRun(
        sizeLabel: label,
        width: width.toInt(),
        height: height.toInt(),
      );

      // Isar calls are real async IO: they must run inside `runAsync` or
      // they never complete in the testWidgets fake-async zone.
      late TrackerRepository repo;
      late Isar isar;
      late SweepFixtures fixtures;
      await tester.runAsync(() async {
        isar = await openTestIsar([
          ExerciseSchema,
          GymSchema,
          WorkoutSplitSchema,
          WorkoutSessionSchema,
        ], name: 'isar_visual_$label');
        repo = TrackerRepository(isar);
        await seedExercisesIfNeeded(repo);
        fixtures = await seedSweepFixtures(repo);
      });
      // No isar.close() teardown: Isar's native close never completes inside
      // the fake-async zone, stalling the suite. The temp DB dies with the
      // test process.

      HydratedBloc.storage = InMemoryStorage();
      final cubit = WorkoutCubit(repository: repo);
      addTearDown(cubit.close);
      cubit.startPlanWorkout(
        title: 'Push Pull Legs · Day 1',
        exercises: [
          PlanExercise(exerciseId: fixtures.benchId, name: 'Bench Press'),
          PlanExercise(
            exerciseId: fixtures.inclineId,
            name: 'Incline Bench Press',
            order: 1,
          ),
        ],
        gym: fixtures.secondaryGym,
      );
      cubit.logSet(
        exerciseId: fixtures.benchId,
        exerciseName: 'Bench Press',
        weight: 80,
        reps: 8,
      );
      cubit.logSet(
        exerciseId: fixtures.benchId,
        exerciseName: 'Bench Press',
        weight: 60,
        reps: 10,
        type: SetType.warmup,
      );

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<WorkoutCubit>.value(value: cubit),
            BlocProvider<SettingsCubit>(
              create: (_) => SettingsCubit()
                ..addGraph(
                  const GraphConfig(title: 'Strength - upper body progression'),
                ),
              lazy: false,
            ),
          ],
          child: RepositoryScope(
            repository: repo,
            // Above MaterialApp so captures include dialogs, sheets, toasts
            // and the bottom bar.
            child: RepaintBoundary(
              key: screenshotBoundaryKey,
              child: const MyApp(),
            ),
          ),
        ),
      );

      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );

      // Label of the screen being swept - failure attribution + _FAIL capture
      // naming. Mutable, shared with the settle()/guarded() closures below.
      var current = 'app-start';
      final failures = <String>[];

      // Real delays outside the fake-async zone let Isar's real watcher
      // events reach the StreamBuilders; the pumps advance the fake clock so
      // UI animations (form-error expand, transitions) finish before capture
      // instead of being caught mid-flight. (No pumpAndSettle: loading
      // spinners animate forever under fake time.)
      //
      // Frame exceptions (RenderFlex overflows etc.) do NOT throw in-body -
      // they land in the binding's pending slot. takeException() retrieves
      // and clears it, tagging the failure with the current screen and
      // capturing it before the sweep moves on.
      Future<void> settle() async {
        for (var i = 0; i < 2; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 150)),
          );
          await tester.pump(const Duration(milliseconds: 250));
        }
        final dynamic pending = tester.takeException();
        if (pending != null) {
          failures.add('[$current] $pending');
          await recorder.captureFailure(current);
        }
      }

      // Isar's `watch(fireImmediately: true)` initial results arrive through
      // real-async windows; wait until the expected data is on screen before
      // capturing (20 rounds ≈ 6 s cap, then capture whatever is there).
      Future<void> settleForData(bool Function() found) async {
        for (var i = 0; i < 20 && !found(); i++) {
          await settle();
        }
      }

      // No on-stage loading spinner left (finders skip Offstage tabs).
      bool dataLoaded() => !tester.any(find.byType(CircularProgressIndicator));

      void switchTab(int index) {
        tester
            .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
            .onChange!(index);
      }

      // Wraps an interactive step: hard failures (tap/expect) capture the
      // broken screen, then rethrow to fail the test from the real cause.
      Future<void> guarded(String what, Future<void> Function() body) async {
        current = what;
        print('SCREENSHOT-SWEEP: $what @ $label');
        try {
          await body();
        } catch (e) {
          failures.add('[$what] $e');
          await recorder.captureFailure(what);
          rethrow;
        }
      }

      // Push a page onto the root navigator (how the app really presents
      // these screens - pushTo paints the route's theme background), capture
      // after settle, then pop. Capture must happen before the pop:
      // afterwards the boundary shows the base page again.
      // [dataReady] gates the capture on stream-backed content arriving.
      //
      // Route/dialog transitions are driven by the fake clock - runAsync
      // delays don't advance them, so pump(350 ms) is what actually completes
      // the 250 ms pushTo transition (without it the pushed page
      // builds but stays invisible and the capture shows the page beneath).
      Future<void> visit(
        String page,
        Widget pageWidget, {
        bool Function()? dataReady,
      }) => guarded(page, () async {
        unawaited(pushTo<void>(navigator.context, pageWidget));
        // Two pumps: one frame starts the transition, the second advances
        // the fake clock past it (a bare pump doesn't move the clock).
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await settle();
        if (dataReady != null) {
          await settleForData(dataReady);
        }
        try {
          await recorder.capture(page);
        } finally {
          navigator.pop();
          // Two pumps: one frame starts the transition, the second advances
          // the fake clock past it (a bare pump doesn't move the clock).
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          await settle();
        }
      });

      await settle();

      // Tab roots - real shell including the bottom bar. Tab switching via
      // onChange (hit-testing is brittle under the Offstage navigators).
      await guarded('Feed tab', () async {
        await settleForData(dataLoaded);
        await recorder.capture('Feed tab');
      });
      await guarded('History tab (list)', () async {
        switchTab(1);
        await settleForData(() => tester.any(find.text('Calendar')));
        await recorder.capture('History tab (list)');
      });
      await guarded('History calendar', () async {
        await tester.tap(find.text('Calendar'));
        await settle();
        await recorder.capture('History calendar');
      });
      await guarded('Workout tab (in progress)', () async {
        switchTab(2);
        await settle();
        await recorder.capture('Workout tab (in progress)');
      });
      await guarded('Editor tab', () async {
        switchTab(3);
        await settleForData(() => tester.any(find.textContaining('Push Day')));
        await recorder.capture('Editor tab');
      });
      await guarded('Exercises tab', () async {
        switchTab(4);
        await settleForData(() => tester.any(find.text('Bench Press')));
        await recorder.capture('Exercises tab');
      });
      await guarded('Back to Feed tab', () async {
        switchTab(0);
        await settle();
      });

      // Pushed pages.
      await visit('Settings page', const SettingsPage());
      await visit(
        'Gyms page',
        const GymsPage(),
        dataReady: () => tester.any(find.text('Iron Temple')),
      );
      await visit(
        'Progression page',
        const ProgressionPage(),
        dataReady: dataLoaded,
      );
      await visit('New exercise page', const NewExercisePage());
      await visit(
        'Exercise detail page',
        ExerciseDetailPage(exercise: fixtures.bench),
        // The page loads its summary async from Isar; wait for the chart to
        // leave its empty state or the capture shows "0 Sessions".
        dataReady: () => !tester.any(find.text('No data yet')),
      );
      await visit(
        'Session detail page',
        SessionDetailPage(session: fixtures.session, gymName: 'Iron Temple'),
        // Set rows fall back to "Exercise <id>" until the async name map
        // resolves; gate on the real exercise name.
        dataReady: () => tester.any(find.text('Bench Press')),
      );
      await visit(
        'Session edit page',
        SessionEditPage(session: fixtures.session),
        dataReady: () => tester.any(find.text('Bench Press')),
      );
      await visit('Split editor (new)', const SplitEditorPage());
      await visit(
        'Split editor (edit)',
        SplitEditorPage(split: fixtures.split),
      );
      await visit(
        'Split day editor',
        SplitDayEditorPage(day: fixtures.split.splitDays.first),
      );
      await visit(
        'Split day page',
        SplitDayPage(
          splitTitle: fixtures.split.title,
          day: fixtures.split.splitDays.first,
        ),
        dataReady: dataLoaded,
      );
      await visit(
        'Exercise picker page',
        const ExercisePickerPage(),
        dataReady: () => tester.any(find.text('Bench Press')),
      );

      // Dialogs and sheets. These open from the tab page's nested navigator
      // (how the app really presents them), so pop via that navigator.
      final pageContext = tester.element(find.byType(FeedPage));

      Future<void> openAndClose(String what, Future<void> Function() open) =>
          guarded(what, () async {
            unawaited(open());
            // Two pumps: one frame starts the transition, the second advances
            // the fake clock past it (a bare pump doesn't move the clock).
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 350));
            await settle();
            try {
              await recorder.capture(what);
            } finally {
              Navigator.of(pageContext).pop();
              // Two pumps: one frame starts the transition, the second advances
              // the fake clock past it (a bare pump doesn't move the clock).
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 350));
              await settle();
            }
          });

      await openAndClose(
        'Graph editor sheet',
        () => GraphEditor.show(
          pageContext,
          exercises: fixtures.exercises,
          initial: const GraphConfig(title: 'Strength - upper body'),
        ),
      );
      await openAndClose(
        'Edit gym dialog',
        () => showFDialog<void>(
          context: pageContext,
          builder: (_, _, _) => EditGymDialog(
            title: 'Edit Gym',
            initial: Gym(
              name: 'Very Long Gym Name - Westfield Century City',
              description: 'Busy hours',
              order: 1,
            ),
          ),
        ),
      );
      await openAndClose(
        'Gym picker sheet',
        () => promptGym(pageContext, fixtures.allGyms),
      );

      // End-workout confirmation dialog (on a pushed in-progress WorkoutPage).
      await guarded('End-workout dialog', () async {
        unawaited(pushTo<void>(navigator.context, const WorkoutPage()));
        // Two pumps: one frame starts the transition, the second advances
        // the fake clock past it (a bare pump doesn't move the clock).
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await settle();
        await tester.ensureVisible(find.text('End Workout'));
        await settle();
        await tester.tap(find.text('End Workout'));
        // Two pumps: one frame starts the transition, the second advances
        // the fake clock past it (a bare pump doesn't move the clock).
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await settle();
        await recorder.capture('End-workout dialog');
        await tester.tap(find.text('Keep going'));
        // Two pumps: one frame starts the transition, the second advances
        // the fake clock past it (a bare pump doesn't move the clock).
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await settle();
        await tester.runAsync(cubit.endWorkout);
        await settle();
        navigator.pop(); // the pushed WorkoutPage
        // Two pumps: one frame starts the transition, the second advances
        // the fake clock past it (a bare pump doesn't move the clock).
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await settle();
      });

      // The session is ended now - the Workout tab shows its idle state.
      await guarded('Workout tab (idle)', () async {
        switchTab(2);
        await settle();
        await recorder.capture('Workout tab (idle)');
      });

      // Fire any pending hydration-debounce timers before the binding checks
      // for leaked timers, and restore the platform override before the
      // foundation invariant check (addTearDown runs too late for both).
      await tester.pump(const Duration(seconds: 5));
      debugDefaultTargetPlatformOverride = null;

      if (failures.isNotEmpty) {
        fail('Render failures during sweep:\n${failures.join('\n---\n')}');
      }
    });
  }
}
