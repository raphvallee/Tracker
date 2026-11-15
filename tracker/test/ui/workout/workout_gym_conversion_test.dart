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

  testWidgets('a machine done at home opens converted at another gym', (
    tester,
  ) async {
    useTallWindow(tester);
    // Real Isar IO only progresses inside tester.runAsync, and there is no
    // tearDown close: native close never completes in the fake-async zone.
    late TrackerRepository repo;
    late int legPress;
    late Gym hotel;
    await tester.runAsync(() async {
      final isar = await openTestIsar([
        WorkoutSessionSchema,
        ExerciseSchema,
        GymSchema,
        WorkoutSplitSchema,
      ], name: 'workout_gym_conversion');
      repo = TrackerRepository(isar);
      legPress = await repo.exercises.put(
        Exercise(
          title: 'Leg Press',
          primaryMuscle: [Muscle.quadriceps],
          equipment: [Equipment.machine],
        ),
      );
      final home = await repo.gyms.put(
        Gym(name: 'Iron Temple', isPrimary: true),
      );
      final hotelId = await repo.gyms.put(
        Gym(
          name: 'Hotel gym',
          order: 1,
          perExerciseMultipliers: [
            GymExerciseMultiplier(
              exerciseId: legPress,
              multiplier: 0.9,
              estimate: 0.9,
              samples: 6,
              spread: 0.01,
            ),
          ],
          machineSetups: [
            GymMachineSetup(exerciseId: legPress, note: 'Seat 4'),
          ],
        ),
      );
      hotel = (await repo.gyms.getById(hotelId))!;
      await repo.sessions.put(
        WorkoutSession(
          title: 'Legs',
          startTime: DateTime.now().subtract(const Duration(days: 5)),
          gymId: home,
          sets: [
            for (var i = 0; i < 3; i++)
              WorkoutSet(exerciseId: legPress, weight: 180, reps: 10, order: i),
          ],
        ),
      );
    });

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

    final cubit = WorkoutCubit(repository: repo)
      ..startWorkout(gym: hotel)
      ..addExercise(exerciseId: legPress, name: 'Leg Press');
    addTearDown(cubit.close);
    final settings = SettingsCubit()
      ..setUnit(WeightUnit.kilograms)
      ..setNumberEntry(NumberEntry.phoneKeyboard)
      ..setEffectiveReps(true);
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
    tester
        .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
        .onChange!(2);

    // The overview already reads last time as it would be here.
    await pumpUntil(find.textContaining('last ≈ 200 kg × 10'));
    await tester.tap(find.text('Leg Press').first);

    // Last time at home, about 200 here, from the hotel's factor; the rows
    // open on the converted weight, and the machine's setup is there.
    await pumpUntil(find.text('Hotel gym ×0.90, from 6 workouts'));
    expect(find.text('180 kg × 10'), findsOneWidget);
    expect(find.text('Seat 4'), findsOneWidget);
    await pumpUntil(find.text('Log 200 kg × 10'));

    // Set 1 went heavier than the guess: the sets after it follow.
    cubit.logSet(
      exerciseId: legPress,
      exerciseName: 'Leg Press',
      weight: 210,
      reps: 10,
    );
    await pumpUntil(find.text('Log 210 kg × 10'));

    // Rated very easy (RPE 6, where 8 is taken for last time's unrated
    // set): with effective reps the sets after it go up about 5% more.
    cubit.setRpe(0, 6);
    await pumpUntil(find.text('Log 220 kg × 10'));
  });
}
