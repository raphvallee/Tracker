// WorkoutSplit persistence with embedded days and sets.
// One Isar-backed case per file: each *_test.dart runs in its own
// flutter_tester process with a fresh libisar native worker pool (see
// docs/TESTING_ISAR_CI.md).

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_split.dart';

import '../../testing/test_helpers.dart';

void main() {
  late Isar isar;
  late TrackerRepository repo;

  setUpAll(initIsarCore);

  setUp(() async {
    isar = await openTestIsar([
      ExerciseSchema,
      GymSchema,
      WorkoutSessionSchema,
      WorkoutSplitSchema,
    ], name: 'split_repository');
    repo = TrackerRepository(isar);
  });

  tearDown(() => isar.close());

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
                sets: [
                  PlannedSet(order: 0, minReps: 8),
                  PlannedSet(order: 1, minReps: 8, maxReps: 12),
                ],
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
      // Nested planned sets round-trip, including fixed vs. range.
      final sets = fetched.splitDays.first.exercises.first.sets;
      expect(sets, hasLength(2));
      expect(sets[0].minReps, 8);
      expect(sets[0].maxReps, isNull);
      expect(sets[1].minReps, 8);
      expect(sets[1].maxReps, 12);
      // Legacy items without sets persist with an empty list.
      expect(fetched.splitDays.first.exercises.last.sets, isEmpty);

      expect(await repo.splits.delete(id), isTrue);
      expect(await repo.splits.getById(id), isNull);
    },
  );
}
