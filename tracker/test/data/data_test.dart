// Data/persistence integration tests. These open a real Isar DB in a throwaway
// temp directory (no path_provider) and exercise CRUD through TrackerRepository,
// plus Isar stream watchers. Covers: seed, exercise/gym/split/session CRUD,
// embedded split days, and the exercise watcher.

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/data/services/seed.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/muscle.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/models/workout_split.dart';

import '../../testing/test_helpers.dart';

final _schemas = <CollectionSchema<dynamic>>[
  ExerciseSchema,
  GymSchema,
  WorkoutSessionSchema,
  WorkoutSplitSchema,
];

void main() {
  late Isar isar;
  late TrackerRepository repo;

  setUpAll(initIsarCore);

  setUp(() async {
    isar = await openTestIsar(_schemas, name: 'data_test');
    repo = TrackerRepository(isar);
  });

  tearDown(() => isar.close());

  test(
    'local-day queries are half-open across DST; getBetween stays inclusive',
    () async {
      // DST acceptance run: TZ=America/New_York flutter test test/data
      // Boundary instants are stored as UTC, just like any other absolute instant.
      for (final day in [DateTime(2026, 3, 8), DateTime(2026, 11, 1)]) {
        final end = DateTime(day.year, day.month, day.day + 1);
        final beforeId = await repo.sessions.put(
          WorkoutSession(
            startTime: day.toUtc().subtract(const Duration(microseconds: 1)),
          ),
        );
        final startId = await repo.sessions.put(
          WorkoutSession(startTime: day.toUtc()),
        );
        final lastId = await repo.sessions.put(
          WorkoutSession(
            startTime: end.toUtc().subtract(const Duration(microseconds: 1)),
          ),
        );
        final endId = await repo.sessions.put(
          WorkoutSession(startTime: end.toUtc()),
        );
        final result = await repo.sessions.getForDate(day);
        expect(result.map((session) => session.id), [lastId, startId]);
        // A UTC argument is interpreted by the local date of its instant too.
        expect(
          (await repo.sessions.getForDate(
            end.toUtc().subtract(const Duration(minutes: 1)),
          )).map((session) => session.id),
          [lastId, startId],
        );
        expect(
          (await repo.sessions.getBetween(
            day,
            end,
          )).map((session) => session.id),
          [endId, lastId, startId],
        );
        expect((await repo.sessions.getBetween(end, end)).single.id, endId);
        for (final id in [beforeId, startId, lastId, endId]) {
          await repo.sessions.delete(id);
        }
      }
    },
  );

  test('seed populates the exercise library once', () async {
    expect(await repo.exercises.count(), 0);
    await repo.exercises.putAll(seedExercises());
    expect(await repo.exercises.count(), greaterThan(0));
  });

  test('exercise CRUD round-trips through the repository', () async {
    final id = await repo.exercises.put(
      Exercise(
        title: 'Bench Press',
        primaryMuscle: [Muscle.chest],
        equipment: [Equipment.barbell],
        movementPattern: MovementPattern.push,
      ),
    );

    final fetched = await repo.exercises.getById(id);
    expect(fetched, isNotNull);
    expect(fetched!.title, 'Bench Press');
    expect(fetched.primaryMuscle, [Muscle.chest]);
    expect(fetched.equipment, [Equipment.barbell]);

    fetched.title = 'Incline Bench Press';
    await repo.exercises.put(fetched);
    expect((await repo.exercises.getById(id))!.title, 'Incline Bench Press');

    expect(await repo.exercises.delete(id), isTrue);
    expect(await repo.exercises.getById(id), isNull);
  });

  test('gym CRUD and primary lookup', () async {
    final gymId = await repo.gyms.put(Gym(name: 'Home', isPrimary: true));
    await repo.gyms.put(Gym(name: 'Commercial', isPrimary: false));

    final primary = await repo.gyms.getPrimary();
    expect(primary, isNotNull);
    expect(primary!.name, 'Home');

    expect((await repo.gyms.getById(gymId))!.name, 'Home');
    expect(await repo.gyms.getAll(), hasLength(2));
    expect(await repo.gyms.delete(gymId), isTrue);
    expect(await repo.gyms.getAll(), hasLength(1));
  });

  test(
    'workout split CRUD preserves embedded days and exercise items',
    () async {
      final split = WorkoutSplit(
        title: 'PPL',
        description: 'Push / Pull / Legs',
        order: 0,
        splitDays: [
          WorkoutSplitDay(
            title: 'Push',
            order: 0,
            exercises: [
              ExerciseItem(
                exerciseId: 1,
                order: 0,
                targetSets: 4,
                targetReps: 6,
              ),
              ExerciseItem(exerciseId: 2, order: 1),
            ],
          ),
        ],
      );

      final id = await repo.splits.put(split);
      final fetched = await repo.splits.getById(id);

      expect(fetched, isNotNull);
      expect(fetched!.splitDays, hasLength(1));
      expect(fetched.splitDays.first.exercises, hasLength(2));
      expect(fetched.splitDays.first.exercises.first.exerciseId, 1);
      expect(fetched.splitDays.first.exercises.first.targetSets, 4);

      expect(await repo.splits.delete(id), isTrue);
      expect(await repo.splits.getById(id), isNull);
    },
  );

  test('create exercise + split, add/reorder day exercises, delete', () async {
    final benchId = await repo.exercises.put(
      Exercise(
        title: 'Bench Press',
        primaryMuscle: [Muscle.chest],
        equipment: [Equipment.barbell],
        movementPattern: MovementPattern.push,
      ),
    );
    final squatId = await repo.exercises.put(
      Exercise(
        title: 'Squat',
        primaryMuscle: [Muscle.quadriceps],
        equipment: [Equipment.barbell],
        movementPattern: MovementPattern.legs,
      ),
    );

    final split = WorkoutSplit(
      title: 'PPL',
      description: 'Push / Pull / Legs',
      order: 0,
      splitDays: [
        WorkoutSplitDay(
          title: 'Push',
          order: 0,
          exercises: [
            ExerciseItem(exerciseId: benchId, order: 0),
            ExerciseItem(exerciseId: squatId, order: 1),
          ],
        ),
      ],
    );
    final id = await repo.splits.put(split);

    var fetched = (await repo.splits.getById(id))!;
    expect(fetched.title, 'PPL');
    expect(fetched.splitDays.single.exercises, hasLength(2));
    expect(fetched.splitDays.single.exercises[0].exerciseId, benchId);

    // Reorder: squat becomes the first exercise of the day.
    fetched.splitDays.single.exercises = [
      ExerciseItem(exerciseId: squatId, order: 0),
      ExerciseItem(exerciseId: benchId, order: 1),
    ];
    await repo.splits.put(fetched);

    final reread = (await repo.splits.getById(id))!;
    final orders = reread.splitDays.single.exercises
        .map((e) => (e.exerciseId, e.order))
        .toList();
    expect(orders, [(squatId, 0), (benchId, 1)]);

    // Delete the split.
    expect(await repo.splits.delete(id), isTrue);
    expect(await repo.splits.getById(id), isNull);
  });

  test(
    'workout session persists with embedded sets and warmup flags',
    () async {
      final gymId = await repo.gyms.put(Gym(name: 'Home', isPrimary: true));

      final id = await repo.sessions.put(
        WorkoutSession(
          title: 'Push A',
          startTime: DateTime(2026, 1, 1, 9),
          endTime: DateTime(2026, 1, 1, 10),
          gymId: gymId,
          sets: [
            WorkoutSet(
              exerciseId: 1,
              weight: 100,
              reps: 5,
              type: SetType.working,
              order: 0,
            ),
            WorkoutSet(
              exerciseId: 1,
              weight: 60,
              reps: 8,
              type: SetType.warmup,
              order: 1,
            ),
          ],
        ),
      );

      final fetched = await repo.sessions.getById(id);
      expect(fetched, isNotNull);
      expect(fetched!.title, 'Push A');
      expect(fetched.gymId, gymId);
      expect(fetched.sets, hasLength(2));
      expect(fetched.sets[0].weight, 100);
      expect(fetched.sets[0].type, SetType.working);
      expect(fetched.sets[0].isWarmup, isFalse);
      expect(fetched.sets[1].isWarmup, isTrue);

      expect(await repo.sessions.getAll(), hasLength(1));
      expect((await repo.sessions.getRecent()).single.id, fetched.id);
      expect(await repo.sessions.getRecent(limit: 1), hasLength(1));
      expect(
        (await repo.sessions.getForDate(DateTime(2026, 1, 1))).single.id,
        fetched.id,
      );
      expect(
        (await repo.sessions.getBetween(
          DateTime(2026, 1, 1, 9),
          DateTime(2026, 1, 1, 10),
        )).single.id,
        fetched.id,
      );
      expect(() => repo.sessions.getRecent(limit: 0), throwsArgumentError);
      expect(
        () => repo.sessions.getBetween(
          DateTime(2026, 1, 2),
          DateTime(2026, 1, 1),
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'repository exercise watcher emits initial and updated values',
    () async {
      final values = <List<Exercise>>[];
      final subscription = repo.exercises.watchAll().listen(values.add);
      addTearDown(subscription.cancel);

      await waitFor(() => values.isNotEmpty);
      expect(values.last, isEmpty);

      await repo.exercises.put(
        Exercise(
          title: 'Test Squat',
          primaryMuscle: [Muscle.quadriceps],
          equipment: [Equipment.barbell],
          movementPattern: MovementPattern.legs,
        ),
      );
      await waitFor(() => values.any((list) => list.length == 1));
      expect(values.last.single.title, 'Test Squat');
    },
  );
}
