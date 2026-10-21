// Tier 2 capture: drives the full past-session edit + delete flow in the real
// app window (feature branch only): History > detail > Edit > edit a set via
// the dialog > Save > updated detail > Delete > confirmation > list without
// the session. Throwaway data (in-memory HydratedBloc storage + temp Isar).
//
//   pwsh ./capture-app-media.ps1 -Mode video -Seconds 40 \
//     -Test tracker/integration_test/capture_session_edit_flow_test.dart
// ignore_for_file: avoid_print
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
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/main.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';
import 'package:window_size/window_size.dart';

import '../testing/fakes/in_memory_storage.dart';
import '../testing/test_helpers.dart';

Future<void> main() async {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Fully live frames so what the window shows matches what the test pumps.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(initIsarCore);

  testWidgets('capture: edit + delete a past session end to end', (
    tester,
  ) async {
    // This test bypasses main() (throwaway data below), so it must set the
    // desktop window title itself: capture-app-media.ps1 locates the window
    // via -Title (the pre-Dart caption is lowercase 'tracker' from
    // windows/runner/main.cpp). A unique title keeps the capture isolated
    // from the user's real Tracker app window when one is running.
    if (Platform.isWindows) setWindowTitle('TrackerCapture');

    HydratedBloc.storage = InMemoryStorage();
    final isar = await openTestIsar([
      ExerciseSchema,
      GymSchema,
      WorkoutSessionSchema,
    ], name: 'isar_capture_session_edit_flow');
    final repo = TrackerRepository(isar);
    await seedExercisesIfNeeded(repo);
    final cubit = WorkoutCubit(repository: repo);

    final exercises = await repo.exercises.getAll();
    final bench = exercises.firstWhere((e) => e.title == 'Bench Press');
    final gymId = await repo.gyms.put(
      Gym(name: 'Iron Temple', isPrimary: true),
    );
    await repo.sessions.put(
      WorkoutSession(
        title: 'Push Day',
        startTime: DateTime.now().subtract(const Duration(hours: 2)),
        endTime: DateTime.now().subtract(const Duration(hours: 1)),
        gymId: gymId,
        sets: [
          WorkoutSet(
            exerciseId: bench.id,
            weight: 60,
            reps: 10,
            type: SetType.warmup,
            order: 0,
          ),
          WorkoutSet(exerciseId: bench.id, weight: 82.5, reps: 8, order: 1),
          WorkoutSet(exerciseId: bench.id, weight: 80, reps: 6, order: 2),
        ],
      ),
    );

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

    Future<void> pause([int ms = 1500]) =>
        Future<void>.delayed(Duration(milliseconds: ms));

    // ---- drive the UI ----------------------------------------------------
    // History tab > session detail.
    tester
        .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
        .onChange!(1);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Push Day'));
    await tester.pumpAndSettle();
    await pause(2000); // detail page with Edit + Delete session

    // Edit > tap the 80 kg set row > per-set editor dialog.
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await pause(2000); // edit page
    await tester.tap(find.text('80 kg × 6'));
    await tester.pumpAndSettle();
    await pause(2000); // Edit set dialog

    // Change the weight, save the dialog, then save the session.
    final fields = find.descendant(
      of: find.byType(FDialog),
      matching: find.byType(EditableText),
    );
    await tester.enterText(fields.first, '90');
    await pause(500);
    await tester.tap(
      find.descendant(of: find.byType(FDialog), matching: find.text('Save')),
    );
    await tester.pumpAndSettle();
    await pause(1000);
    await tester.tap(find.text('Save')); // editor app-bar action
    await tester.pumpAndSettle();
    await pause(2500); // detail page shows 90 kg × 6

    // Delete the session with confirmation (from the detail page itself).
    await tester.tap(find.text('Delete session'));
    await tester.pumpAndSettle();
    await pause(2000); // Delete session? confirmation dialog
    await tester.tap(find.widgetWithText(FButton, 'Delete'));
    await tester.pumpAndSettle();
    await pause(2500); // back at the history list, session gone
    // ----------------------------------------------------------------------

    // The script captures the window externally. Keep the window on screen
    // until it signals "capture finished" via build/captures/.capture-done.
    const doneFile = 'build/captures/.capture-done';
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (!File(doneFile).existsSync() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  });
}
