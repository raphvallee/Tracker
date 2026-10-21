// Feed cubit tests: the retry flow must open a FRESH repository subscription
// after an error (a rebuilt dead subscription can never recover).

import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/data/repositories/workout_session_repository.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/ui/feed/view_models/feed_cubit.dart';

import '../../../testing/test_helpers.dart';

/// Fails the first watch, then serves one recorded session.
class _FlakySessionRepo extends WorkoutSessionRepository {
  _FlakySessionRepo(super.isar);

  int calls = 0;

  @override
  Stream<List<WorkoutSession>> watchRecent({int limit = 5}) {
    calls += 1;
    if (calls == 1) return Stream.error(StateError('injected failure'));
    return Stream.value(<WorkoutSession>[
      WorkoutSession(
        title: 'Push day',
        startTime: DateTime(2026, 1, 1, 10),
        endTime: DateTime(2026, 1, 1, 11),
        sets: [WorkoutSet(exerciseId: 1, weight: 60, reps: 8)],
      ),
    ]);
  }
}

class _FlakyTrackerRepo extends TrackerRepository {
  _FlakyTrackerRepo(super.isar, this._sessions);

  final _FlakySessionRepo _sessions;

  @override
  _FlakySessionRepo get sessions => _sessions;
}

void main() {
  setUpAll(initIsarCore);

  test(
    'retry() opens a fresh subscription and recovers from an error',
    () async {
      final isar = await openTestIsar([
        WorkoutSessionSchema,
      ], name: 'feed_cubit_retry');
      final sessionRepo = _FlakySessionRepo(isar);
      final repo = _FlakyTrackerRepo(isar, sessionRepo);
      final cubit = FeedCubit(repository: repo);
      addTearDown(cubit.close);
      addTearDown(isar.close);

      // Load: the first subscription fails -> error state.
      cubit.load();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(cubit.state.status, FeedStatus.error);
      expect(cubit.state.sessions, isEmpty);
      expect(sessionRepo.calls, 1);

      // Retry: a fresh subscription succeeds -> ready with sessions.
      cubit.retry();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(cubit.state.status, FeedStatus.ready);
      expect(cubit.state.sessions, hasLength(1));
      expect(cubit.state.sessions.first.title, 'Push day');
      expect(sessionRepo.calls, 2);
    },
  );

  test(
    'no repository wired: load() is a no-op and the state stays initial',
    () async {
      final cubit = FeedCubit();
      addTearDown(cubit.close);

      cubit.load();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(cubit.state.status, FeedStatus.loading);
    },
  );
}
