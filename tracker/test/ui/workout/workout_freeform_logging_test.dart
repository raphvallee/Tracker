// One Isar-backed case per file: each *_test.dart runs in its own
// flutter_tester process with a fresh libisar native worker pool (see
// docs/TESTING_ISAR_CI.md).

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/muscle.dart';
import 'package:tracker/domain/models/number_entry.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/main.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/splits/view_models/split_drafts_cubit.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/test_helpers.dart';
import '../../../testing/workout_helpers.dart';

void main() {
  setUpAll(initIsarCore);

  setUp(() {
    HydratedBloc.storage = InMemoryStorage();
  });

  testWidgets('a free workout adds an exercise and logs last session again', (
    tester,
  ) async {
    useTallWindow(tester);
    // The picker and the prefill read the repository, so pump the real
    // shell scoped to a test Isar (pumpApp has no RepositoryScope). Real
    // Isar IO only progresses inside tester.runAsync, and there is no
    // tearDown close: native close never completes in the fake-async zone,
    // the temp DB dies with the test process instead.
    late TrackerRepository repo;
    late int exerciseId;
    await tester.runAsync(() async {
      final isar = await openTestIsar([
        WorkoutSessionSchema,
        ExerciseSchema,
        GymSchema,
        WorkoutSplitSchema,
      ], name: 'workout_ui_freeform');
      repo = TrackerRepository(isar);
      exerciseId = await repo.exercises.put(
        Exercise(
          title: 'Bench Press',
          primaryMuscle: [Muscle.chest],
          equipment: [Equipment.barbell],
        ),
      );
      await repo.sessions.put(
        WorkoutSession(
          title: 'Last week',
          startTime: DateTime.now().subtract(const Duration(days: 7)),
          sets: [
            WorkoutSet(
              exerciseId: exerciseId,
              weight: 40,
              reps: 10,
              type: SetType.warmup,
            ),
            WorkoutSet(exerciseId: exerciseId, weight: 60, reps: 8, order: 1),
          ],
        ),
      );
    });

    // Timed pumps that leave the real event loop room to land widget-zone
    // Isar reads (pumpAndSettle would hang on the live Isar watchers).
    Future<void> pumpUntil(Finder finder) async {
      for (var i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        if (finder.evaluate().isNotEmpty) return;
      }
      fail('expected $finder to become visible');
    }

    final cubit = WorkoutCubit(repository: repo);
    addTearDown(cubit.close);
    final settings = SettingsCubit()
      ..setUnit(WeightUnit.kilograms)
      ..setNumberEntry(NumberEntry.phoneKeyboard);
    addTearDown(settings.close);
    await tester.pumpWidget(
      RepositoryProvider<TrackerRepository>.value(
        value: repo,
        child: RepositoryScope(
          repository: repo,
          child: MultiBlocProvider(
            providers: [
              BlocProvider<WorkoutCubit>.value(value: cubit),
              BlocProvider<SettingsCubit>.value(value: settings),
              BlocProvider<SplitDraftsCubit>(
                create: (_) => SplitDraftsCubit(repository: repo),
              ),
            ],
            child: const MyApp(),
          ),
        ),
      ),
    );
    await pumpUntil(find.byType(FBottomNavigationBar));

    // No split yet: the start view offers an empty workout.
    tester
        .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
        .onChange!(2);
    await pumpUntil(find.text('Start empty workout'));
    await tester.tap(find.text('Start empty workout'));
    await pumpUntil(find.text('Add an exercise to start logging sets.'));
    expect(find.text('Free workout'), findsOneWidget);

    // Adding an exercise opens its page straight away.
    await tester.tap(find.text('Add exercise').last);
    await pumpUntil(find.text('Bench Press').hitTestable());
    await tester.tap(find.text('Bench Press'));
    await pumpUntil(find.textContaining('Last time'));
    expect(cubit.state.plan.single.exerciseId, exerciseId);

    // Last session's two sets come back as two prefilled rows, warm-up
    // included, so each one is a single tap.
    expect(find.textContaining('W 40 × 10, 60 × 8'), findsOneWidget);
    expect(weightField(1), findsOneWidget);
    expect(find.text('Log 40 kg × 10'), findsOneWidget);
    await tester.tap(find.text('Log 40 kg × 10'));
    await pumpUntil(find.text('Log 60 kg × 8'));
    await tester.tap(find.text('Log 60 kg × 8'));
    await pumpUntil(find.text('Back to overview'));

    expect(cubit.state.sets.map((s) => (s.weight, s.reps, s.type)), [
      (40, 10, SetType.warmup),
      (60, 8, SetType.working),
    ]);
    expect(
      cubit.state.sets.every((s) => s.exerciseName == 'Bench Press'),
      isTrue,
    );

    await tester.tap(find.text('Back to overview'));
    await pumpUntil(find.text('2 sets logged'));
    expect(find.text('2 sets'), findsOneWidget, reason: 'free workout header');
  });
}
