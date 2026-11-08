// One Isar-backed case per file: each *_test.dart runs in its own
// flutter_tester process with a fresh libisar native worker pool (see
// docs/TESTING_ISAR_CI.md).

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_session.dart';

import '../../testing/test_helpers.dart';

void main() {
  late Isar isar;
  late TrackerRepository repo;

  setUpAll(initIsarCore);

  setUp(() async {
    isar = await openTestIsar([
      GymSchema,
      WorkoutSessionSchema,
    ], name: 'session_sync_queries');
    repo = TrackerRepository(isar);
  });

  tearDown(() => isar.close());

  test('sync History queries: newest first, exact local days, gyms', () async {
    final starts = [
      DateTime(2026, 3, 3, 23, 59, 59),
      DateTime(2026, 3, 4),
      DateTime(2026, 3, 4, 9),
      DateTime(2026, 3, 4, 23, 59, 59),
      DateTime(2026, 3, 5),
      DateTime(2026, 1, 1, 12),
    ];
    for (final (i, start) in starts.indexed) {
      await repo.sessions.put(WorkoutSession(title: 'S$i', startTime: start));
    }
    await repo.gyms.put(Gym(name: 'B', order: 1));
    await repo.gyms.put(Gym(name: 'A', order: 0));

    final newestFirst = [...starts]..sort((a, b) => b.compareTo(a));
    expect(repo.sessions.getStartTimesSync(), newestFirst);
    expect(repo.sessions.getAllSync().map((s) => s.startTime), newestFirst);

    expect(
      repo.sessions.getOnLocalDaySync(DateTime(2026, 3, 4)).map((s) => s.title),
      ['S3', 'S2', 'S1'],
    );
    expect(repo.sessions.getOnLocalDaySync(DateTime(2026, 3, 6)), isEmpty);
    expect(repo.gyms.getAllSync().map((g) => g.name), ['A', 'B']);

    final changes = expectLater(repo.sessions.watchChanges(), emits(anything));
    await repo.sessions.put(WorkoutSession(startTime: DateTime(2026, 3, 6)));
    await changes;
  });
}
