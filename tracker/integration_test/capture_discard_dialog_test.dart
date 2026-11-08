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

    tester
        .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
        .onChange!(3);
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Split'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(FTextField, 'Split name'),
      'Push Day',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(FLucideIcons.chevronLeft));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);

    const doneFile = 'build/captures/.capture-done';
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (!File(doneFile).existsSync() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  });
}
