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

    tester
        .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
        .onChange!(1);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Push Day'));
    await tester.pumpAndSettle();
    await pause(2000);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await pause(2000);
    // Open the last set in place and step its weight up: the row turns
    // Edited and the save bar slides up.
    await tester.tap(find.textContaining('80 kg × 6'));
    await tester.pumpAndSettle();
    await pause(1500);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.bySemanticsLabel('Increase weight'));
      await tester.pumpAndSettle();
      await pause(300);
    }
    await pause(1000);

    final dateRow = find.text('Started');
    if (dateRow.evaluate().isNotEmpty) {
      await tester.tap(dateRow);
      await tester.pumpAndSettle();
      await pause(2500);
      // Tapping outside the sheet closes it without saving.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await pause(2500);

    // Delete is behind the edit page's menu, and asks first.
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await pause(1500);
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is FButton && w.semanticsTooltip == 'Workout options',
      ),
    );
    await tester.pumpAndSettle();
    await pause(1500);
    await tester.tap(find.text('Delete workout'));
    await tester.pumpAndSettle();
    await pause(2000);
    await tester.tap(find.widgetWithText(FButton, 'Delete'));
    await tester.pumpAndSettle();
    await pause(2500);

    const doneFile = 'build/captures/.capture-done';
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (!File(doneFile).existsSync() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  });
}
