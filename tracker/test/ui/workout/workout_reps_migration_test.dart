// Reps storage widening (int to double): a legacy DB migrates intact.
// One Isar-backed case per file: each *_test.dart runs in its own
// flutter_tester process with a fresh libisar native worker pool (see
// docs/TESTING_ISAR_CI.md).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:tracker/data/services/db.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_session.dart';

import '../../../testing/test_helpers.dart';

void main() {
  setUpAll(initIsarCore);

  test('legacy data migrates through DbInstance with intact reps', () async {
    // Fixture written by the pre-widening schema, where WorkoutSet.reps was
    // an int (see test/fixtures/reps_int_v1/): two sets with reps 5 and 8.
    final gz = File('test/fixtures/reps_int_v1/default.isar.gz')
        .readAsBytesSync();
    final dir = await Directory.systemTemp.createTemp('reps_migration');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/default.isar').writeAsBytesSync(GZipCodec().decode(gz));

    // DbInstance.getIsar uses path_provider for its directory; exercise the
    // same migration logic against this fixture directory instead.
    await DbInstance.migrateRepsToIntToDouble(dir.path);

    final isar = await Isar.open(
      [WorkoutSessionSchema, ExerciseSchema, GymSchema],
      directory: dir.path,
      name: 'default',
    );
    final repo = TrackerRepository(isar);

    final sessions = await repo.sessions.getAll();
    expect(sessions, hasLength(1));
    expect(sessions.single.title, 'Old session');
    // Whole-number int reps load as whole doubles - no zeroes, no rounding.
    expect(sessions.single.sets.map((s) => s.reps).toList(), [5.0, 8.0]);
    expect(sessions.single.sets.map((s) => s.weight).toList(), [100.0, 90.0]);
    expect(sessions.single.sets.last.isWarmup, isTrue);
    expect(sessions.single.sets.map((s) => s.order).toList(), [0, 1]);

    await isar.close();
  });
}
