// Gym factors worked out from the database. One Isar-backed case per file
// (docs/TESTING_ISAR_CI.md).
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/data/services/gym_factors.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/muscle.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/services/gym_equivalence.dart';

import '../../testing/test_helpers.dart';

void main() {
  setUpAll(initIsarCore);

  test('machines learn their factor; set by hand and setups stay', () async {
    final isar = await openTestIsar([
      ExerciseSchema,
      GymSchema,
      WorkoutSessionSchema,
    ], name: 'isar_gym_factors');
    addTearDown(() => isar.close(deleteFromDisk: true));
    final repo = TrackerRepository(isar);
    final legPress = await repo.exercises.put(
      Exercise(
        title: 'Leg Press',
        primaryMuscle: [Muscle.quadriceps],
        equipment: [Equipment.machine],
      ),
    );
    final pulldown = await repo.exercises.put(
      Exercise(
        title: 'Lat Pulldown',
        primaryMuscle: [Muscle.lats],
        equipment: [Equipment.cable],
      ),
    );
    final bench = await repo.exercises.put(
      Exercise(
        title: 'Bench Press',
        primaryMuscle: [Muscle.chest],
        equipment: [Equipment.barbell],
      ),
    );
    final home = await repo.gyms.put(Gym(name: 'Home', isPrimary: true));
    final hotel = await repo.gyms.put(
      Gym(
        name: 'Hotel gym',
        order: 1,
        perExerciseMultipliers: [
          GymExerciseMultiplier(
            exerciseId: pulldown,
            multiplier: 1.2,
            manual: true,
          ),
        ],
      ),
    );
    final start = DateTime(2026, 6, 1);
    WorkoutSession session(int day, int gymId, double scale) => WorkoutSession(
      startTime: start.add(Duration(days: day)),
      gymId: gymId,
      sets: [
        for (final (id, from) in [(legPress, 150.0), (pulldown, 60.0)])
          WorkoutSet(
            exerciseId: id,
            weight: (from + day / 4) * scale,
            reps: 10,
          ),
        // Plates weigh the same: the bench press reads the same anywhere.
        WorkoutSet(exerciseId: bench, weight: 80 + day / 8, reps: 5),
      ],
    );
    await repo.sessions.putAll([
      for (var day = 0; day <= 60; day += 3) session(day, home, 1),
      session(20, hotel, 1 / 0.9),
      session(40, hotel, 1 / 0.9),
    ]);

    await refreshGymFactors(repo, now: start.add(const Duration(days: 61)));

    var gym = (await repo.gyms.getById(hotel))!;
    final estimated = gymFactorOf(gym, legPress);
    expect(estimated.source, FactorSource.estimated);
    expect(estimated.value, closeTo(0.9, 0.01));
    expect(estimated.samples, 2);
    // Set by hand: it stays, and learns the estimate beside it.
    final manual = gymFactorOf(gym, pulldown);
    expect(manual.source, FactorSource.manual);
    expect(manual.value, 1.2);
    expect(manual.estimate, closeTo(0.9, 0.01));
    // Plates are not measured.
    expect(gymFactorOf(gym, bench).source, FactorSource.gym);
    expect(gym.multiplier, closeTo(0.9, 0.01));
    expect((await repo.gyms.getById(home))!.perExerciseMultipliers, isEmpty);

    // Back on the estimate, then set by hand again.
    await repo.gyms.clearExerciseFactor(hotel, pulldown);
    gym = (await repo.gyms.getById(hotel))!;
    expect(gymFactorOf(gym, pulldown).source, FactorSource.estimated);
    expect(gymFactorOf(gym, pulldown).value, closeTo(0.9, 0.01));
    await repo.gyms.setExerciseFactor(hotel, legPress, 0.95);
    await repo.gyms.setMachineSetup(hotel, legPress, 'Seat 4');
    gym = (await repo.gyms.getById(hotel))!;
    expect(gymFactorOf(gym, legPress).value, 0.95);
    expect(setupNoteOf(gym, legPress), 'Seat 4');

    // A new workout leaves both alone.
    await refreshGymFactors(repo, now: start.add(const Duration(days: 61)));
    gym = (await repo.gyms.getById(hotel))!;
    expect(gymFactorOf(gym, legPress).source, FactorSource.manual);
    expect(gymFactorOf(gym, legPress).value, 0.95);
    expect(setupNoteOf(gym, legPress), 'Seat 4');

    await repo.gyms.setMachineSetup(hotel, legPress, '');
    expect(setupNoteOf((await repo.gyms.getById(hotel))!, legPress), isNull);
  });
}
