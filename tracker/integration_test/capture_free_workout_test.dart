import 'dart:io';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/data/services/seed.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/main.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/core/ui/set_type_chip.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';
import 'package:window_size/window_size.dart';

import '../testing/fakes/in_memory_storage.dart';
import '../testing/test_helpers.dart';

Future<void> main() async {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(initIsarCore);

  testWidgets('capture: free workout logged card by card', (tester) async {
    // This test bypasses main() (throwaway data below), so it must set the
    // desktop window title itself: capture-app-media.ps1 locates the window
    // via -Title. A unique title keeps the capture isolated from the user's
    // real Tracker app window when one is running.
    if (Platform.isWindows) setWindowTitle('TrackerCapture');

    HydratedBloc.storage = InMemoryStorage();
    final isar = await openTestIsar([
      ExerciseSchema,
      GymSchema,
      WorkoutSplitSchema,
      WorkoutSessionSchema,
    ], name: 'isar_capture_free_workout');
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

    Future<void> pause([int ms = 1200]) =>
        Future<void>.delayed(Duration(milliseconds: ms));

    Future<void> reveal(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
    }

    Future<void> tapOn(Finder finder, {int pauseMs = 1200}) async {
      await reveal(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
      await pause(pauseMs);
    }

    Finder card(String exercise) => find
        .ancestor(of: find.text(exercise), matching: find.byType(FCard))
        .first;

    Finder input(String exercise, int index) => find
        .descendant(
          of: find
              .descendant(of: card(exercise), matching: find.byType(FTextField))
              .at(index),
          matching: find.byType(EditableText),
        )
        .first;

    Finder chip(String exercise, int row) => find
        .descendant(of: card(exercise), matching: find.byType(SetTypeChip))
        .at(row);

    Future<void> typeRow(
      String exercise,
      int row,
      String weight,
      String reps, {
      bool commit = true,
    }) async {
      await reveal(input(exercise, row * 2));
      await tester.enterText(input(exercise, row * 2), weight);
      await tester.pumpAndSettle();
      await pause(500);
      await tester.enterText(input(exercise, row * 2 + 1), reps);
      await tester.pumpAndSettle();
      await pause(500);
      if (commit) {
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        await pause();
      }
    }

    Future<void> pickExercise(String query, String title) async {
      await tapOn(find.text('Add exercise'));
      await tester.enterText(find.byType(EditableText).first, query);
      await tester.pumpAndSettle();
      await pause(900);
      await tapOn(find.text(title), pauseMs: 1500);
    }

    // The script starts recording a few seconds after the titled window
    // appears: hold the first screen until it does.
    await pause(5000);

    // Start a free workout (no gyms, so no gym prompt).
    tester
        .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
        .onChange!(2);
    await tester.pumpAndSettle();
    await pause();
    await tapOn(find.text('Start Workout'), pauseMs: 1800);

    // Each exercise gets its own card.
    await pickExercise('bench', 'Bench Press');

    // Warm-up toggled before typing, via the row's chip.
    await tapOn(chip('Bench Press', 0), pauseMs: 900);
    await typeRow('Bench Press', 0, '40', '10');
    await typeRow('Bench Press', 1, '80', '8');

    // Add set, then type into the lower blank row: the set lands in the
    // first blank row and no stale copy is left behind.
    await tapOn(find.text('Add set'), pauseMs: 900);
    await typeRow('Bench Press', 3, '82.5', '6');
    await pause(800);

    // Mouse click on the chip of a typed row: the blur logs it, the toggle
    // then marks it as a warm-up.
    await typeRow('Bench Press', 3, '60', '12', commit: false);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(chip('Bench Press', 3)));
    await mouse.down(tester.getCenter(chip('Bench Press', 3)));
    await mouse.up();
    await tester.pumpAndSettle();
    await mouse.removePointer();
    await pause(1800);

    // A logged set's chip flips it back and forth.
    await tapOn(chip('Bench Press', 1), pauseMs: 900);
    await tapOn(chip('Bench Press', 1), pauseMs: 1200);

    // Clearing a logged row shifts the later sets up.
    await typeRow('Bench Press', 2, '', '');
    await pause(800);

    // A second exercise, logged in its own card.
    await pickExercise('squat', 'Squat');
    await typeRow('Squat', 0, '100', '5');
    await typeRow('Squat', 1, '100', '5');

    // Picking an exercise that already has a card says so.
    await pickExercise('bench', 'Bench Press');
    await pause(1500);

    // Removing an exercise with sets asks first.
    await tapOn(
      find.descendant(of: card('Squat'), matching: find.byIcon(FLucideIcons.x)),
      pauseMs: 1800,
    );
    await tapOn(find.widgetWithText(FButton, 'Remove'), pauseMs: 1500);

    await tapOn(find.text('End Workout'), pauseMs: 1500);
    await tapOn(find.text('End & save'), pauseMs: 1500);
    tester
        .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
        .onChange!(1);
    await tester.pumpAndSettle();
    await pause(2500);

    const doneFile = 'build/captures/.capture-done';
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (!File(doneFile).existsSync() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  });
}
