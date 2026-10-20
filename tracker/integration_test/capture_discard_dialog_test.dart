// Tier 2 capture test: boots the real app window on Windows with throwaway
// data (in-memory HydratedBloc storage + temp Isar, never the user's real
// app data) and leaves the split editor's "Discard changes?" confirmation
// dialog on screen for capture.
//
// Used with the repo-root helper (see docs/CAPTURING_MEDIA.md):
//
//   pwsh ./capture-app-media.ps1 -Mode screenshot -Test tracker/integration_test/capture_discard_dialog_test.dart
//
// ignore_for_file: avoid_print
import 'dart:io';

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

  testWidgets('capture: split editor discard confirmation dialog', (
    tester,
  ) async {
    // This test bypasses main() (throwaway data below), so it must set the
    // desktop window title itself: capture-app-media.ps1 locates the window
    // by the exact title 'Tracker' (the pre-Dart caption is lowercase
    // 'tracker' from windows/runner/main.cpp).
    if (Platform.isWindows) setWindowTitle('Tracker');

    HydratedBloc.storage = InMemoryStorage();
    final isar = await openTestIsar([
      ExerciseSchema,
      GymSchema,
      WorkoutSplitSchema,
      WorkoutSessionSchema,
    ], name: 'isar_capture_discard_dialog');
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

    // ---- drive the UI ----------------------------------------------------
    // Open the split-editor tab (WorkoutsEditor), then the split editor.
    tester
        .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
        .onChange!(3);
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Split'));
    await tester.pumpAndSettle();

    // Make an edit so the PopScope dirty guard intercepts back navigation.
    await tester.enterText(
      find.widgetWithText(FTextField, 'Split name'),
      'Push Day',
    );
    await tester.pumpAndSettle();

    // Tap the app-bar back chevron -> PopScope opens the discard dialog.
    await tester.tap(find.byIcon(FLucideIcons.chevronLeft));
    await tester.pumpAndSettle();

    // Sanity check: the dialog must be on screen before capture.
    expect(find.text('Discard changes?'), findsOneWidget);
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
