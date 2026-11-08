// WorkoutSession persistence and date queries.
// One Isar-backed case per file: each *_test.dart runs in its own
// flutter_tester process with a fresh libisar native worker pool (see
// docs/TESTING_ISAR_CI.md).

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
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
    ], name: 'session_repository');
    repo = TrackerRepository(isar);
  });

  tearDown(() => isar.close());

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
}
