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
    ], name: 'gym_repository');
    repo = TrackerRepository(isar);
  });

  tearDown(() => isar.close());

  test('getAll sorts by order and getPrimary finds the primary gym', () async {
    await repo.gyms.put(Gym(name: 'Commercial', order: 1));
    await repo.gyms.put(Gym(name: 'Home', isPrimary: true, order: 0));
    await repo.gyms.put(Gym(name: 'Hotel', order: 2));

    expect((await repo.gyms.getAll()).map((g) => g.name), [
      'Home',
      'Commercial',
      'Hotel',
    ]);
    expect((await repo.gyms.getPrimary())!.name, 'Home');
  });
}
