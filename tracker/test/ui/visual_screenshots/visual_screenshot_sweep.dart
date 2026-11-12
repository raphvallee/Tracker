// Shared body: one visual_screenshots_<size>_test.dart per window size runs
// it, so each Isar-backed case gets its own process (docs/TESTING_ISAR_CI.md).
// ignore_for_file: avoid_print

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:isar_community/isar.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/data/services/seed.dart';
import 'package:tracker/domain/models/effort_scale.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/graph_config.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/number_entry.dart';
import 'package:tracker/domain/models/split_draft.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/domain/services/workout_dates.dart';
import 'package:tracker/main.dart';
import 'package:tracker/ui/analytics/view_models/analytics_data.dart';
import 'package:tracker/ui/analytics/widgets/graph_editor.dart';
import 'package:tracker/ui/analytics/widgets/graph_page.dart';
import 'package:tracker/ui/analytics/widgets/graph_tile.dart';
import 'package:tracker/ui/analytics/widgets/progression_page.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/core/ui/effort_sheet.dart';
import 'package:tracker/ui/core/ui/graph_chart.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/exercises/widgets/exercise_detail_page.dart';
import 'package:tracker/ui/exercises/widgets/new_exercise_page.dart';
import 'package:tracker/ui/feed/widgets/feed_page.dart';
import 'package:tracker/ui/history/widgets/calendar/history_calendar.dart';
import 'package:tracker/ui/history/widgets/session_detail_page.dart';
import 'package:tracker/ui/history/widgets/session_edit_page.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/settings/widgets/gyms_page.dart';
import 'package:tracker/ui/settings/widgets/settings_list.dart';
import 'package:tracker/ui/settings/widgets/settings_page.dart';
import 'package:tracker/ui/settings/widgets/splits_settings_page.dart';
import 'package:tracker/ui/settings/widgets/workout_settings_page.dart';
import 'package:tracker/ui/splits/view_models/split_drafts_cubit.dart';
import 'package:tracker/ui/splits/widgets/new_split_sheet.dart';
import 'package:tracker/ui/splits/widgets/review_changes_sheet.dart';
import 'package:tracker/ui/splits/widgets/set_target_sheet.dart';
import 'package:tracker/ui/splits/widgets/split_day_editor_page.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';
import 'package:tracker/ui/workout/widgets/exercise_page.dart';
import 'package:tracker/ui/workout/widgets/exercise_picker_page.dart';
import 'package:tracker/ui/workout/widgets/gym_picker.dart';
import 'package:tracker/ui/workout/widgets/start_view.dart';
import 'package:tracker/ui/workout/widgets/workout_page.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/screenshot_helpers.dart';
import '../../../testing/test_fixtures.dart';
import '../../../testing/test_fonts.dart';
import '../../../testing/test_helpers.dart';

/// Runs the whole capture sweep at one window size. Called by one
/// `visual_screenshots_<size>_test.dart` per size - never register several
/// sizes in one file.
Future<void> captureScreensAt(
  WidgetTester tester,
  String label,
  double width,
  double height,
) async {
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
  startSweepWorkout(cubit, fixtures);
  final drafts = SplitDraftsCubit(repository: repo);
  addTearDown(drafts.close);
  final names = {
    fixtures.benchId: 'Bench Press',
    fixtures.inclineId: 'Incline Bench Press',
  };

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<WorkoutCubit>.value(value: cubit),
        BlocProvider<SplitDraftsCubit>.value(value: drafts),
        BlocProvider<SettingsCubit>(
          create: (_) => SettingsCubit()
            ..addGraph(GraphConfig(exerciseId: fixtures.benchId))
            ..addGraph(
              GraphConfig(
                exerciseId: fixtures.benchId,
                metric: GraphMetric.record1rm,
              ),
            )
            ..addGraph(
              GraphConfig(
                exerciseId: fixtures.inclineId,
                metric: GraphMetric.volume,
              ),
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

  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);

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

  Future<void> settleForData(bool Function() found) async {
    for (var i = 0; i < 20 && !found(); i++) {
      await settle();
    }
  }

  bool dataLoaded() => !tester.any(find.byType(FCircularProgress));

  void switchTab(int index) {
    tester
        .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
        .onChange!(index);
  }

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
  await guarded('Feed analytics', () async {
    // The graphs sit under the recent activity: scroll down to them.
    final feed = find
        .descendant(
          of: find.byType(FeedPage),
          matching: find.byType(Scrollable),
        )
        .first;
    await settleForData(() => tester.any(find.byType(GraphTile)));
    await tester.scrollUntilVisible(
      find.text('Add graph'),
      200,
      scrollable: feed,
    );
    await settle();
    await recorder.capture('Feed analytics');
    await tester.drag(feed, const Offset(0, 4000));
    await settle();
  });
  await guarded('History tab', () async {
    switchTab(1);
    await settleForData(() => tester.any(find.text('Upper Body')));
    await recorder.capture('History tab');
  });
  await guarded('Workout tab (in progress)', () async {
    switchTab(2);
    await settle();
    await recorder.capture('Workout tab (in progress)');
  });
  await guarded('Splits tab', () async {
    switchTab(3);
    await settle();
    await settleForData(() => tester.any(find.textContaining('Push Day')));
    await recorder.capture('Splits tab');
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

  await visit(
    'Settings page',
    const SettingsPage(),
    dataReady: () => tester.any(find.textContaining('Iron Temple')),
  );
  await visit('Workout settings page', const WorkoutSettingsPage());
  await visit('Splits settings page', const SplitsSettingsPage());
  await visit(
    'Gyms page',
    const GymsPage(),
    dataReady: () => tester.any(find.text('Iron Temple')),
  );
  await visit(
    'Graph page',
    GraphPage(
      index: 0,
      data: AnalyticsData(
        sessions: fixtures.allSessions,
        exercises: fixtures.exercises,
        gyms: fixtures.allGyms,
      ),
    ),
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
    dataReady: () => tester.any(find.byType(GraphChart)),
  );
  await visit(
    'Session detail page',
    SessionDetailPage(session: fixtures.session, gymName: 'Iron Temple'),
    dataReady: () => tester.any(find.text('Bench Press')),
  );
  await visit(
    'Session edit page',
    SessionEditPage(session: fixtures.session),
    dataReady: () => tester.any(find.text('Bench Press')),
  );
  Future<void> pushSettled(Widget page) async {
    unawaited(pushTo<void>(navigator.context, page));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await settle();
  }

  Future<void> popSettled() async {
    navigator.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await settle();
  }

  await guarded('Session detail page (folded)', () async {
    await pushSettled(
      SessionDetailPage(session: fixtures.session, gymName: 'Iron Temple'),
    );
    // Fold the first exercise to its best set.
    await tester.tap(find.text('Bench Press').last);
    await settle();
    try {
      await recorder.capture('Session detail page (folded)');
    } finally {
      await popSettled();
    }
  });
  await guarded('Session edit page (edited set)', () async {
    await pushSettled(SessionEditPage(session: fixtures.session));
    // Open the working set and step its weight up: the row shows its
    // steppers and rating, the Edited tag and the Was line, and the save
    // bar slides up.
    await tester.tap(find.textContaining('82.5 kg × 8').last);
    await settle();
    await tester.tap(find.bySemanticsLabel('Increase weight').last);
    await settle();
    try {
      await recorder.capture('Session edit page (edited set)');
      current = 'Session edit page (menu)';
      await tester.tap(fButtonByTooltip('Workout options').last);
      await settle();
      await recorder.capture('Session edit page (menu)');
      current = 'Delete workout dialog';
      await tester.tap(find.text('Delete workout').last);
      await settle();
      await recorder.capture('Delete workout dialog');
      await tester.tap(find.text('Cancel').last);
      await settle();
    } finally {
      await popSettled();
    }
  });
  await guarded('Session edit page (keypad)', () async {
    await pushSettled(SessionEditPage(session: fixtures.session));
    await tester.tap(find.textContaining('82.5 kg × 8').last);
    await settle();
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is TextField && w.focusNode?.debugLabel == 'edit set weight',
      ),
    );
    // One settle opens the keypad and starts lifting the row above it, the
    // second lets that scroll finish.
    await settle();
    await settle();
    try {
      await recorder.capture('Session edit page (keypad)');
    } finally {
      FocusManager.instance.primaryFocus?.unfocus();
      await settle();
      await popSettled();
    }
  });
  await visit(
    'Exercise page',
    ExercisePage(exerciseId: fixtures.benchId),
    // Last session loaded: its values sit small under the logged ones.
    dataReady: () => tester.any(find.text('82.5')),
  );
  await guarded('Exercise page (keypad)', () async {
    unawaited(
      pushTo<void>(
        navigator.context,
        ExercisePage(exerciseId: fixtures.benchId),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await settleForData(() => tester.any(find.text('82.5')));
    await tester.tap(
      find
          .byWidgetPredicate(
            (w) => w is TextField && (w.controller?.text.isEmpty ?? false),
          )
          .first,
    );
    // One settle opens the keypad and starts lifting the row above it, the
    // second lets that scroll finish.
    await settle();
    await settle();
    try {
      await recorder.capture('Exercise page (keypad)');
    } finally {
      FocusManager.instance.primaryFocus?.unfocus();
      await settle();
      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await settle();
    }
  });
  await guarded('Exercise page (errors)', () async {
    unawaited(
      pushTo<void>(
        navigator.context,
        ExercisePage(exerciseId: fixtures.benchId),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await settleForData(() => tester.any(find.text('82.5')));
    // The open row (set 2, after the logged warm-up and set 1): a weight
    // and a rep count out of range.
    Finder field(String label) => find
        .byWidgetPredicate(
          (w) => w is TextField && w.focusNode?.debugLabel == label,
        )
        .at(2);
    await tester.enterText(field('set weight'), '20000');
    await tester.enterText(field('set reps'), '0.05');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle();
    try {
      await recorder.capture('Exercise page (errors)');
    } finally {
      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await settle();
    }
  });
  await guarded('Exercise page (compared with last time)', () async {
    unawaited(
      pushTo<void>(
        navigator.context,
        ExercisePage(exerciseId: fixtures.benchId),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await settleForData(() => tester.any(find.text('82.5')));
    // Open the logged set 1: it was lighter than last time's.
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Set 1 logged',
      ),
    );
    await settle();
    try {
      await recorder.capture('Exercise page (compared with last time)');
    } finally {
      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await settle();
    }
  });
  await visit(
    'Split day editor',
    SplitDayEditorPage(splitId: fixtures.split.id, dayIndex: 0),
    dataReady: () => tester.any(find.text('Bench Press')),
  );
  await visit(
    'Exercise picker page',
    const ExercisePickerPage(),
    dataReady: () => tester.any(find.text('Bench Press')),
  );

  final pageContext = tester.element(find.byType(FeedPage));

  Future<void> openAndClose(
    String what,
    Future<void> Function() open, {
    bool root = false,
  }) => guarded(what, () async {
    unawaited(open());
    // Two pumps: one frame starts the transition, the second advances
    // the fake clock past it (a bare pump doesn't move the clock).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await settle();
    try {
      await recorder.capture(what);
    } finally {
      Navigator.of(pageContext, rootNavigator: root).pop();
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
      initial: GraphConfig(exerciseId: fixtures.benchId),
    ),
    root: true,
  );
  await openAndClose(
    'Edit gym sheet',
    () => editGymSheet(
      pageContext,
      title: 'Edit Gym',
      initial: Gym(
        name: 'Very Long Gym Name - Westfield Century City',
        description: 'Busy hours',
        order: 1,
      ),
    ),
    root: true,
  );
  await openAndClose(
    'Split details sheet',
    () => editSplitDetails(
      pageContext,
      title: 'New split',
      confirmLabel: 'Create',
    ),
    root: true,
  );
  await openAndClose(
    'Gym picker sheet',
    () => showGymPicker(
      pageContext,
      fixtures.allGyms,
      currentId: fixtures.allGyms.first.id,
      oneWorkoutOnly: true,
    ),
    root: true,
  );
  await openAndClose(
    'Settings choice sheet',
    () => showChoiceSheet<NumberEntry>(
      pageContext,
      title: 'Number entry',
      description: 'What opens when you tap a weight or reps',
      options: numberEntryOptions,
      value: NumberEntry.keypad,
      note: 'Also used for planned sets in Splits.',
    ),
    root: true,
  );
  await openAndClose(
    'Rep target sheet',
    () => showSetTargetSheet(
      pageContext,
      title: 'Rep target',
      subtitle: 'For exercises you add to a split day',
      sets: const [SetTarget(8, 12)],
      index: 0,
      allowWarmup: false,
    ),
    root: true,
  );
  await openAndClose(
    'New split sheet',
    () => showNewSplitSheet(pageContext),
    root: true,
  );
  await openAndClose(
    'Set target sheet',
    () => showSetTargetSheet(
      pageContext,
      title: 'Bench Press, set 2',
      subtitle: 'Push Day. Saved as 8-12 reps.',
      sets: const [
        SetTarget.warmup(12),
        SetTarget(8, 12),
        SetTarget(8, 12),
        SetTarget(8, 12),
      ],
      index: 1,
    ),
    root: true,
  );
  await openAndClose(
    'History calendar sheet',
    () => showHistoryCalendar(
      pageContext,
      index: WorkoutDateIndex.fromSessions(fixtures.allSessions),
    ),
    root: true,
  );
  await openAndClose(
    'Effort sheet',
    () => showEffortSheet(
      pageContext,
      title: 'Set 2 effort',
      scale: EffortScale.rpe,
      rpe: 8,
    ),
    root: true,
  );

  // Unsaved edits: a changed target, a renamed day and a new day.
  drafts.edit(
    fixtures.split,
    (draft) => draft
        .updateDay(
          0,
          (day) => day.updateExercise(
            0,
            (exercise) => exercise.withSet(2, const SetTarget(6, 8)),
          ),
        )
        .updateDay(1, (day) => day.copyWith(title: 'Pull Day'))
        .addDay('Leg Day'),
  );
  await guarded('Splits tab (unsaved changes)', () async {
    switchTab(3);
    await settle();
    await recorder.capture('Splits tab (unsaved changes)');
    switchTab(0);
    await settle();
  });
  await visit(
    'Split day editor (unsaved changes)',
    SplitDayEditorPage(splitId: fixtures.split.id, dayIndex: 0),
    dataReady: () => tester.any(find.text('Bench Press')),
  );
  await openAndClose(
    'Review changes sheet',
    () => showReviewChangesSheet(
      pageContext,
      split: fixtures.split,
      names: names,
    ),
    root: true,
  );
  drafts.discard(fixtures.split.id);

  await guarded('End-workout dialog', () async {
    unawaited(pushTo<void>(navigator.context, const WorkoutPage()));
    // Two pumps: one frame starts the transition, the second advances
    // the fake clock past it (a bare pump doesn't move the clock).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await settle();
    await tester.tap(find.text('Finish'));
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
    navigator.pop();
    // Two pumps: one frame starts the transition, the second advances
    // the fake clock past it (a bare pump doesn't move the clock).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await settle();
  });

  await guarded('Workout tab (idle)', () async {
    switchTab(2);
    await settle();
    // The next day follows the workout just saved.
    await settleForData(() => tester.any(find.textContaining('Start Pull')));
    await recorder.capture('Workout tab (idle)');
  });

  await guarded('Workout tab (idle, long plan)', () async {
    // A day too long for any of the sizes: its plan runs past the fold.
    final library = await tester.runAsync(repo.exercises.getAll);
    final long = WorkoutSplit(
      title: 'Upper Lower',
      order: 1,
      splitDays: [
        WorkoutSplitDay(
          title: 'Upper',
          exercises: [
            for (final (i, exercise) in library!.take(8).indexed)
              ExerciseItem(
                exerciseId: exercise.id,
                order: i,
                sets: [
                  for (var k = 0; k < 3; k++)
                    PlannedSet(order: k, minReps: 8, maxReps: 12),
                ],
              ),
          ],
        ),
      ],
    );
    await tester.runAsync(() => repo.splits.put(long));
    tester
        .element(find.byType(MyApp))
        .read<SettingsCubit>()
        .setCurrentSplit(long.id);
    await settleForData(() => tester.any(find.text('Start Upper')));
    await settle();
    await recorder.capture('Workout tab (idle, long plan)');
  });

  await guarded('History tab (restore strip)', () async {
    // A workout discarded a moment ago can still come back.
    cubit.startWorkout();
    cubit.addExercise(exerciseId: fixtures.benchId, name: 'Bench Press');
    cubit.logSet(
      exerciseId: fixtures.benchId,
      exerciseName: 'Bench Press',
      weight: 80,
      reps: 8,
    );
    await cubit.discardWorkout();
    switchTab(1);
    await settle();
    try {
      await recorder.capture('History tab (restore strip)');
    } finally {
      switchTab(2);
      await settle();
    }
  });

  await guarded('Train from sheet', () async {
    // The split's name opens the sheet, whose last row starts an empty
    // workout.
    await tester.tap(
      find.descendant(
        of: find.byType(StartView),
        matching: find.text('Upper Lower'),
      ),
    );
    await settleForData(() => tester.any(find.text('Train from')));
    await settle();
    await recorder.capture('Train from sheet');
    // A tap outside the sheet closes it.
    await tester.tapAt(const Offset(4, 4));
    await settle();
  });

  await guarded('Workout tab (free workout)', () async {
    cubit.startWorkout();
    cubit.addExercise(exerciseId: fixtures.benchId, name: 'Bench Press');
    cubit.addExercise(
      exerciseId: fixtures.inclineId,
      name: 'Incline Bench Press',
    );
    cubit.logSet(
      exerciseId: fixtures.benchId,
      exerciseName: 'Bench Press',
      weight: 60,
      reps: 10,
      type: SetType.warmup,
    );
    cubit.logSet(
      exerciseId: fixtures.benchId,
      exerciseName: 'Bench Press',
      weight: 80,
      reps: 8,
    );
    await settle();
    await recorder.capture('Workout tab (free workout)');
  });

  // Fire any pending hydration-debounce timers before the binding checks
  // for leaked timers, and restore the platform override before the
  // foundation invariant check (addTearDown runs too late for both).
  await tester.pump(const Duration(seconds: 5));
  debugDefaultTargetPlatformOverride = null;

  if (failures.isNotEmpty) {
    fail('Render failures during sweep:\n${failures.join('\n---\n')}');
  }
}
