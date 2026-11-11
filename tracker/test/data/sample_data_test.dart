// Test mode's sample data. One Isar-backed case per file
// (docs/TESTING_ISAR_CI.md).
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/data/services/sample_data.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/graph_config.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/domain/services/graph_series.dart';
import 'package:tracker/domain/services/split_rotation.dart';

import '../../testing/test_helpers.dart';

void main() {
  setUpAll(initIsarCore);

  test('fills an empty database with a full, recent history', () async {
    final isar = await openTestIsar([
      ExerciseSchema,
      GymSchema,
      WorkoutSplitSchema,
      WorkoutSessionSchema,
    ], name: 'isar_sample_data');
    addTearDown(() => isar.close(deleteFromDisk: true));
    final repo = TrackerRepository(isar);
    final now = DateTime(2026, 11, 11, 20);

    final sample = await seedSampleData(repo, now: now);

    final exercises = await repo.exercises.getAll();
    final gyms = await repo.gyms.getAll();
    final splits = await repo.splits.getAll();
    final sessions = await repo.sessions.getAll();
    expect(exercises, isNotEmpty);
    expect(gyms.map((g) => g.name), ['Iron Temple', 'Hotel gym']);
    expect(gyms.where((g) => g.isPrimary), hasLength(1));
    expect(splits.map((s) => s.title), ['Push Pull Legs', 'Upper Lower']);
    expect(sample.currentSplitId, splits.first.id);

    // Fourteen months, most weeks trained, the last days included.
    expect(sessions.length, greaterThan(200));
    final dates = sessions.map((s) => s.startTime).toList()..sort();
    expect(now.difference(dates.first).inDays, greaterThan(400));
    expect(now.difference(dates.last).inDays, lessThanOrEqualTo(3));
    expect(dates.every((d) => d.isBefore(now)), isTrue);

    // Every set is of a known exercise; warm-ups and ratings are there.
    final ids = exercises.map((e) => e.id).toSet();
    final sets = sessions.expand((s) => s.sets).toList();
    expect(sets.every((set) => ids.contains(set.exerciseId)), isTrue);
    expect(sets.where((set) => set.isWarmup), isNotEmpty);
    expect(sets.where((set) => set.rpe != null), isNotEmpty);
    // Both gyms were trained at, and some workouts had no split.
    expect(sessions.map((s) => s.gymId).toSet(), gyms.map((g) => g.id).toSet());
    expect(sessions.where((s) => s.splitId == null), isNotEmpty);

    // Up next follows the current split's rotation.
    final visits = await repo.sessions.getSplitVisits();
    final next = upNext(splits, visits)!;
    expect(next.split.id, sample.currentSplitId);
    expect(next.dayIndex, isNotNull);

    // The bench press got stronger, with records along the way.
    final bench = graphSeries(
      sessions: sessions,
      exerciseId: sample.exerciseIds['Bench Press'],
      metric: GraphMetric.record1rm,
      range: GraphTimeframe.all,
      now: now,
    );
    expect(bench.change, greaterThan(10));
    expect(bench.sessions.where((s) => s.isRecord).length, greaterThan(5));

    // The same day gives the same data.
    final again = await openTestIsar([
      ExerciseSchema,
      GymSchema,
      WorkoutSplitSchema,
      WorkoutSessionSchema,
    ], name: 'isar_sample_data_again');
    addTearDown(() => again.close(deleteFromDisk: true));
    final repoAgain = TrackerRepository(again);
    await seedSampleData(repoAgain, now: now);
    final sessionsAgain = await repoAgain.sessions.getAll();
    expect(sessionsAgain.length, sessions.length);
    expect(
      sessionsAgain.expand((s) => s.sets).map((s) => s.weight).toList(),
      sets.map((s) => s.weight).toList(),
    );
  });
}
