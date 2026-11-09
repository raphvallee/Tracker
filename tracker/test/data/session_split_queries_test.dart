// One Isar-backed case per file: each *_test.dart runs in its own
// flutter_tester process with a fresh libisar native worker pool (see
// docs/TESTING_ISAR_CI.md).

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';

import '../../testing/test_helpers.dart';

void main() {
  late Isar isar;
  late TrackerRepository repo;

  setUpAll(initIsarCore);

  setUp(() async {
    isar = await openTestIsar([
      GymSchema,
      WorkoutSessionSchema,
    ], name: 'session_split_queries');
    repo = TrackerRepository(isar);
  });

  tearDown(() => isar.close());

  test(
    'split visits and previous performance read the latest sessions',
    () async {
      await repo.sessions.put(
        WorkoutSession(
          title: 'Push',
          startTime: DateTime(2026, 3, 1, 9),
          splitId: 7,
          splitDayIndex: 0,
          sets: [
            WorkoutSet(exerciseId: 1, weight: 60, reps: 10, order: 0),
            WorkoutSet(exerciseId: 2, weight: 20, reps: 12, order: 1),
          ],
        ),
      );
      await repo.sessions.put(
        WorkoutSession(title: 'Free', startTime: DateTime(2026, 3, 2, 9)),
      );
      await repo.sessions.put(
        WorkoutSession(
          title: 'Pull',
          startTime: DateTime(2026, 3, 3, 9),
          splitId: 7,
          splitDayIndex: 1,
          sets: [
            WorkoutSet(
              exerciseId: 1,
              weight: 40,
              reps: 12,
              type: SetType.warmup,
              order: 1,
            ),
            WorkoutSet(exerciseId: 1, weight: 62.5, reps: 8, order: 2),
            WorkoutSet(exerciseId: 3, weight: 30, reps: 8, order: 0),
          ],
        ),
      );

      final visits = await repo.sessions.getSplitVisits();
      expect(visits.map((v) => (v.splitId, v.dayIndex)), [(7, 1), (7, 0)]);
      expect(visits.first.startTime, DateTime(2026, 3, 3, 9));

      final bench = await repo.sessions.getPreviousPerformance(1);
      expect(bench!.date, DateTime(2026, 3, 3, 9));
      expect(bench.sets.map((s) => s.weight), [40, 62.5]);
      expect(bench.leadingWarmups, 1);

      final curl = await repo.sessions.getPreviousPerformance(2);
      expect(curl!.sets.single.reps, 12);
      expect(await repo.sessions.getPreviousPerformance(99), isNull);
    },
  );
}
