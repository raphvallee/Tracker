// Interactive keyboard-reveal verification for the two flows called out in
// Refine.md follow-up: (1) the add-graph sheet keeps its full card reachable
// while the title is focused under the keyboard, and (2) the settings rep
// range Min/Max inputs keep their 8px gap when the Max input is focused.
//
// Like visual_screenshots_test.dart this is an inspection capture (PNGs in
// build/test_screenshots), plus hard geometry assertions so the keyboard
// reveal and the input spacing cannot silently regress.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/settings/widgets/settings_page.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

import '../../testing/fakes/in_memory_storage.dart';
import '../../testing/screenshot_helpers.dart';
import '../../testing/test_fixtures.dart';
import '../../testing/test_fonts.dart';
import '../../testing/test_helpers.dart';

const double _keyboardHeight = 300;

/// Phone viewport plus the sweep's minimum window size, where the keyboard
/// leaves little room and the sheet must scroll.
const List<(String, Size)> _sizes = [
  ('400x850-phone', Size(400, 850)),
  ('320x568-min', Size(320, 568)),
];

/// The [FTextField] whose label text is exactly [label].
Finder fieldWithLabel(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is FTextField &&
      widget.label is Text &&
      (widget.label as Text).data == label,
);

void main() {
  setUpAll(initIsarCore);

  for (final (sizeLabel, viewport) in _sizes) {
    for (final (scenario, run)
        in <(String, Future<void> Function(WidgetTester, ScreenshotRecorder))>[
          ('add-graph-sheet', _addGraphSheetScenario),
          ('settings-rep-range', _settingsRepRangeScenario),
        ]) {
      testWidgets('$scenario @$sizeLabel', (tester) async {
        await tester.runAsync(loadTestFonts);
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        // devicePixelRatio 1 keeps the faked keyboard inset in logical pixels.
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final recorder = ScreenshotRecorder(tester);
        recorder.beginRun(
          sizeLabel: 'keyboard-check-$sizeLabel',
          width: viewport.width.toInt(),
          height: viewport.height.toInt(),
        );

        late TrackerRepository repo;
        await tester.runAsync(() async {
          final isar = await openTestIsar([
            ExerciseSchema,
            GymSchema,
            WorkoutSplitSchema,
            WorkoutSessionSchema,
          ], name: 'isar_keyboard_${scenario}_$sizeLabel');
          repo = TrackerRepository(isar);
          await seedExercisesIfNeeded(repo);
          await seedSweepFixtures(repo);
        });

        HydratedBloc.storage = InMemoryStorage();
        final workoutCubit = WorkoutCubit(repository: repo);
        addTearDown(workoutCubit.close);

        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider<WorkoutCubit>.value(value: workoutCubit),
              BlocProvider<SettingsCubit>(
                create: (_) => SettingsCubit(),
                lazy: false,
              ),
            ],
            child: RepositoryScope(
              repository: repo,
              child: RepaintBoundary(
                key: screenshotBoundaryKey,
                child: const MyApp(),
              ),
            ),
          ),
        );
        for (var i = 0; i < 3; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 150)),
          );
          await tester.pump(const Duration(milliseconds: 250));
        }

        await run(tester, recorder);

        // Restore the platform override before the foundation invariant check
        // (addTearDown runs too late for it - see visual_screenshots_test.dart).
        debugDefaultTargetPlatformOverride = null;
      });
    }
  }
}

/// Opens the add-graph sheet, focuses the title with the keyboard up, and
/// checks the whole card stays reachable above the keyboard.
Future<void> _addGraphSheetScenario(
  WidgetTester tester,
  ScreenshotRecorder recorder,
) async {
  expect(
    tester.any(find.text('Add graph')),
    isTrue,
    reason: 'precondition: the feed analytics header is visible',
  );

  await _openKeyboard(tester);
  await tester.tap(find.text('Add graph'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();

  await tester.tap(fieldWithLabel('Title'));
  await tester.pumpAndSettle();
  await recorder.capture('add-graph sheet, title focused, keyboard up');

  final keyboardTop = _keyboardTop(tester);
  final titleRect = tester.getRect(fieldWithLabel('Title'));
  expect(
    titleRect.bottom,
    lessThanOrEqualTo(keyboardTop),
    reason: 'the focused title field must be fully visible above the keyboard',
  );

  // The whole card must remain reachable: scroll to the Save button and
  // confirm it clears the keyboard too.
  await tester.dragUntilVisible(
    find.text('Save'),
    find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(SingleChildScrollView),
    ),
    const Offset(0, -120),
  );
  await tester.pumpAndSettle();
  final saveRect = tester.getRect(find.text('Save'));
  expect(
    saveRect.bottom,
    lessThanOrEqualTo(keyboardTop),
    reason: 'the Save action must be reachable above the keyboard',
  );
  await recorder.capture('add-graph sheet, scrolled to Save');
}

/// Focuses the rep-range Max input under the keyboard and checks the
/// Min/Max inputs keep their 8px horizontal gap.
Future<void> _settingsRepRangeScenario(
  WidgetTester tester,
  ScreenshotRecorder recorder,
) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  unawaited(pushTo<void>(navigator.context, const SettingsPage()));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();

  final minField = fieldWithLabel('Min');
  final maxField = fieldWithLabel('Max');
  expect(minField, findsOneWidget);
  expect(maxField, findsOneWidget);

  double gap() =>
      tester.getRect(maxField).left - tester.getRect(minField).right;
  expect(
    gap(),
    closeTo(8, 0.5),
    reason: 'the Min/Max inputs sit 8px apart before the keyboard opens',
  );

  await _openKeyboard(tester);
  await tester.ensureVisible(maxField);
  // ensureVisible jumps the scroll offset synchronously but the render tree
  // only relayouts on the next frame; without this pump the tap evaluates
  // stale positions and misses.
  await tester.pump();
  await tester.tap(maxField);
  await tester.pumpAndSettle();
  await recorder.capture('settings, rep-range Max focused, keyboard up');

  final keyboardTop = _keyboardTop(tester);
  expect(
    tester.getRect(maxField).bottom,
    lessThanOrEqualTo(keyboardTop),
    reason: 'the focused Max input must be fully visible above the keyboard',
  );
  expect(
    gap(),
    closeTo(8, 0.5),
    reason: 'focusing Max must not change the 8px gap between the inputs',
  );
}

Future<void> _openKeyboard(WidgetTester tester) async {
  tester.view.viewInsets = FakeViewPadding(bottom: _keyboardHeight);
  addTearDown(tester.view.resetViewInsets);
  await tester.pumpAndSettle();
}

/// Bottom edge of the faked keyboard, in logical pixels (devicePixelRatio 1).
double _keyboardTop(WidgetTester tester) =>
    tester.view.physicalSize.height / tester.view.devicePixelRatio -
    _keyboardHeight;
