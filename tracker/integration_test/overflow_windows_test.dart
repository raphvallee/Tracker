import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:isar_community/isar.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/data/services/seed.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/graph_config.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/main.dart';
import 'package:tracker/routing/tab_navigation.dart';
import 'package:tracker/ui/analytics/widgets/graph_editor.dart';
import 'package:tracker/ui/analytics/widgets/progression_page.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/exercises/widgets/exercise_detail_page.dart';
import 'package:tracker/ui/exercises/widgets/new_exercise_page.dart';
import 'package:tracker/ui/feed/widgets/feed_page.dart';
import 'package:tracker/ui/history/widgets/calendar/calendar_grid.dart';
import 'package:tracker/ui/history/widgets/calendar/history_calendar.dart';
import 'package:tracker/ui/history/widgets/session_detail_page.dart';
import 'package:tracker/ui/history/widgets/session_edit_page.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/settings/widgets/gyms_page.dart';
import 'package:tracker/ui/settings/widgets/settings_page.dart';
import 'package:tracker/ui/settings/widgets/splits_settings_page.dart';
import 'package:tracker/ui/settings/widgets/workout_settings_page.dart';
import 'package:tracker/ui/splits/view_models/split_drafts_cubit.dart';
import 'package:tracker/ui/splits/widgets/split_day_editor_page.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';
import 'package:tracker/ui/workout/widgets/exercise_page.dart';
import 'package:tracker/ui/workout/widgets/exercise_picker_page.dart';
import 'package:tracker/ui/workout/widgets/gym_picker.dart';
import 'package:tracker/ui/workout/widgets/workout_page.dart';
import 'package:window_size/window_size.dart';

import '../testing/fakes/in_memory_storage.dart';
import '../testing/test_fixtures.dart';
import '../testing/test_helpers.dart';

const _sizes = <(String, double, double)>[
  ('320x568-min', 320, 568),
  ('640x720-snap-half', 640, 720),
  ('1280x720-default', 1280, 720),
];

void _mark(String what) => debugPrint('SWEEP: $what');

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initIsarCore);

  late TrackerRepository repo;
  late Isar isar;
  late SweepFixtures fixtures;

  setUpAll(() async {
    isar = await openTestIsar([
      ExerciseSchema,
      GymSchema,
      WorkoutSplitSchema,
      WorkoutSessionSchema,
    ], name: 'isar_windows_overflow');
    repo = TrackerRepository(isar);
    await seedExercisesIfNeeded(repo);
    fixtures = await seedSweepFixtures(repo);
  });

  Future<void> resizeWindow(
    String label,
    double width,
    double height, {
    Offset origin = const Offset(40, 40),
  }) async {
    _mark('resizing to $label');
    setWindowFrame(Rect.fromLTWH(origin.dx, origin.dy, width, height));
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final view = WidgetsBinding.instance.platformDispatcher.views.first;
      final scale = view.devicePixelRatio;
      final w = view.physicalSize.width / scale;
      final h = view.physicalSize.height / scale;
      if ((w - width).abs() < 48 && (h - height).abs() < 48) {
        _mark('landed ${w.round()}x${h.round()} (dpr $scale) at $label');
        return;
      }
    }
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final scale = view.devicePixelRatio;
    _mark(
      'WARNING: window never settled near $label; landed '
      '${(view.physicalSize.width / scale).round()}x'
      '${(view.physicalSize.height / scale).round()} (dpr $scale)',
    );
  }

  // A bounded settle: real delays let Isar watchers fire, a pump renders. No
  // pumpAndSettle - loading spinners animate forever.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 2; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await tester.pump();
    }
  }

  Future<WorkoutCubit> pumpRealApp(WidgetTester tester) async {
    HydratedBloc.storage = InMemoryStorage();
    final cubit = WorkoutCubit(repository: repo);
    await tester.pumpWidget(
      RepositoryProvider<TrackerRepository>.value(
        value: repo,
        child: RepositoryScope(
          repository: repo,
          child: MultiBlocProvider(
            providers: [
              BlocProvider<WorkoutCubit>.value(value: cubit),
              BlocProvider<SettingsCubit>(
                create: (_) => SettingsCubit(),
                lazy: false,
              ),
              BlocProvider<SplitDraftsCubit>(
                create: (_) => SplitDraftsCubit(repository: repo),
                lazy: false,
              ),
            ],
            child: const MyApp(),
          ),
        ),
      ),
    );
    await settle(tester);
    return cubit;
  }

  testWidgets('no overflow across all screens', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final sizes = [..._sizes];
    final screens = await getScreenList();
    if (screens.isNotEmpty) {
      final visible = screens.first.visibleFrame;
      sizes.add((
        '${visible.width.round()}x${visible.height.round()}-maximized',
        visible.width,
        visible.height,
      ));
    }

    for (final (label, width, height) in sizes) {
      await resizeWindow(
        label,
        width,
        height,
        origin: label.endsWith('-maximized')
            ? Offset(
                screens.first.visibleFrame.left,
                screens.first.visibleFrame.top,
              )
            : const Offset(40, 40),
      );

      final cubit = await pumpRealApp(tester);
      startSweepWorkout(cubit, fixtures);
      await settle(tester);

      for (final tab in TabName.values) {
        _mark('tab ${tab.name} @ $label');
        HomePageSingleton().changeTab(tab);
        await settle(tester);
      }

      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );

      Future<void> visit(String page, Widget pageWidget) async {
        _mark('$page @ $label');
        unawaited(
          navigator.push(MaterialPageRoute<void>(builder: (_) => pageWidget)),
        );
        await settle(tester);
        navigator.pop();
        await settle(tester);
      }

      await visit('SettingsPage', const SettingsPage());
      await visit('WorkoutSettingsPage', const WorkoutSettingsPage());
      await visit('SplitsSettingsPage', const SplitsSettingsPage());
      await visit('GymsPage', const GymsPage());
      await visit('ProgressionPage', const ProgressionPage());
      await visit('NewExercisePage', const NewExercisePage());
      await visit(
        'ExerciseDetailPage',
        ExerciseDetailPage(exercise: fixtures.bench),
      );
      await visit(
        'SessionDetailPage',
        SessionDetailPage(session: fixtures.session, gymName: 'Iron Temple'),
      );
      await visit(
        'SessionEditPage',
        SessionEditPage(session: fixtures.session),
      );
      await visit(
        'HistoryCalendar',
        Material(
          type: MaterialType.transparency,
          // The app always hosts the calendar in a scrollable.
          child: SingleChildScrollView(
            child: HistoryCalendar(
              index: WorkoutDateIndex.fromSessions(fixtures.allSessions),
              sessionsOn: (day) => [
                for (final s in fixtures.allSessions)
                  if (DateUtils.isSameDay(s.startTime, day)) s,
              ],
              gymNames: fixtures.gymNames,
            ),
          ),
        ),
      );
      await visit('ExercisePage', ExercisePage(exerciseId: fixtures.benchId));
      await visit(
        'SplitDayEditorPage',
        SplitDayEditorPage(splitId: fixtures.split.id, dayIndex: 0),
      );
      await visit('ExercisePickerPage', const ExercisePickerPage());

      HomePageSingleton().changeTab(TabName.feed);
      await settle(tester);
      final pageContext = tester.element(find.byType(FeedPage));

      Future<void> openAndClose(
        String what,
        Future<void> Function() open, {
        bool root = false,
      }) async {
        _mark('$what @ $label');
        unawaited(open());
        await settle(tester);
        Navigator.of(pageContext, rootNavigator: root).pop();
        await settle(tester);
      }

      await openAndClose(
        'GraphEditor sheet',
        () => GraphEditor.show(
          pageContext,
          exercises: fixtures.exercises,
          initial: const GraphConfig(title: 'Strength - upper body'),
        ),
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
        'Gym picker sheet',
        () => promptGym(pageContext, fixtures.allGyms),
      );

      _mark('End-workout dialog @ $label');
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(builder: (_) => const WorkoutPage()),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('Finish'));
      await settle(tester);
      await tester.tap(find.text('Keep going'));
      await settle(tester);
      await cubit.endWorkout();
      await settle(tester);

      // Drain anything the dialog flow left on the root stack: the pushed
      // WorkoutPage survives into the next size otherwise (the retained
      // NavigatorState covers the shell and offstages every later visit).
      navigator.popUntil((route) => route.isFirst);
      await settle(tester);

      _mark('done @ $label');
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    await tester.pump(const Duration(seconds: 5));
    debugDefaultTargetPlatformOverride = null;
  });
}
