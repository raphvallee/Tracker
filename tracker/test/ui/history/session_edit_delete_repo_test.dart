// Runs alone in its own process: each Isar-backed case gets a fresh libisar
// native pool (see session_edit_delete_test.dart for why).

import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';

import '../../../testing/session_edit_helpers.dart';
import '../../../testing/test_helpers.dart';

void main() {
  setUpAll(initIsarCore);

  test('edited/deleted session round-trips through the repository', () async {
    // The exact repository operations the detail page issues after its
    // dialogs: an editor draft put back under the same id, then a delete.
    // (Plain async test so real Isar IO can complete.)
    final isar = await openTestIsar([
      ExerciseSchema,
      GymSchema,
      WorkoutSessionSchema,
    ], name: 'session_edit_delete_repo');
    final repo = TrackerRepository(isar);
    addTearDown(isar.close);

    final gymId = await repo.gyms.put(Gym(name: 'Home', isPrimary: true));
    final session = pastSession(exerciseId: 1, gymId: gymId);
    final id = await repo.sessions.put(session);

    final edited = WorkoutSession(
      title: 'Push (edited)',
      startTime: session.startTime.add(const Duration(hours: 1)),
      endTime: session.endTime,
      gymId: null,
      sets: [
        for (final set in session.sets)
          if (!set.isWarmup)
            WorkoutSet(
              exerciseId: set.exerciseId,
              weight: 90,
              reps: set.reps,
              type: set.type,
              order: set.order,
            ),
      ],
    )..id = id;
    await repo.sessions.put(edited);

    final persisted = (await repo.sessions.getById(id))!;
    expect(persisted.title, 'Push (edited)');
    expect(persisted.gymId, isNull);
    expect(persisted.sets, hasLength(1));
    expect(persisted.sets.single.weight, 90);
    expect(persisted.sets.single.isWarmup, isFalse);

    expect(await repo.sessions.delete(id), isTrue);
    expect(await repo.sessions.getById(id), isNull);
  });
}
