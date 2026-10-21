import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/muscle.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/main.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/history/widgets/session_detail_page.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

import 'test_helpers.dart';

WorkoutSession pastSession({int exerciseId = 1, int? gymId}) => WorkoutSession(
  title: 'Push',
  startTime: DateTime(2026, 1, 1, 9),
  endTime: DateTime(2026, 1, 1, 10),
  gymId: gymId,
  sets: [
    WorkoutSet(
      exerciseId: exerciseId,
      weight: 80,
      reps: 5,
      type: SetType.working,
      order: 0,
    ),
    WorkoutSet(
      exerciseId: exerciseId,
      weight: 60,
      reps: 8,
      type: SetType.warmup,
      order: 1,
    ),
  ],
);

/// Seeds a session into a fresh temp Isar (real IO inside [tester.runAsync],
/// same concession as the visual sweep), then pumps the app shell with the
/// matching [RepositoryScope] and pushes the detail page for that session.
///
/// No isar.close(): native close never completes inside the fake-async zone;
/// the temp DB dies with the test process.
///
/// Returns the repository and the seeded session so tests can read the saved
/// records back and assert what the UI actually persisted.
Future<({TrackerRepository repo, WorkoutSession session})> pumpPersistenceApp(
  WidgetTester tester,
  String dbName, {
  WeightUnit unit = WeightUnit.kilograms,
}) async {
  late TrackerRepository repo;
  late WorkoutSession session;
  await tester.runAsync(() async {
    final isar = await openTestIsar([
      ExerciseSchema,
      GymSchema,
      WorkoutSessionSchema,
    ], name: dbName);
    repo = TrackerRepository(isar);
    final exerciseId = await repo.exercises.put(
      Exercise(
        title: 'Bench Press',
        primaryMuscle: [Muscle.chest],
        equipment: [Equipment.barbell],
        movementPattern: MovementPattern.push,
      ),
    );
    final gymId = await repo.gyms.put(Gym(name: 'Home', isPrimary: true));
    session = pastSession(exerciseId: exerciseId, gymId: gymId);
    await repo.sessions.put(session);
  });

  final cubit = WorkoutCubit(repository: repo);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    RepositoryScope(
      repository: repo,
      child: MultiBlocProvider(
        providers: [
          BlocProvider<WorkoutCubit>.value(value: cubit),
          BlocProvider<SettingsCubit>(
            create: (_) => SettingsCubit()..setUnit(unit),
          ),
        ],
        child: const MyApp(),
      ),
    ),
  );
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  unawaited(
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => SessionDetailPage(session: session),
      ),
    ),
  );
  await settleSessionFlow(tester);
  return (repo: repo, session: session);
}

/// Waits for real Isar writes started from inside the fake-async zone to land.
/// The page issues writes from the widget zone, so each round gives the real
/// event loop time and then pumps so completions run. Returns once [done]
/// reports true, or fails after a bounded number of rounds.
Future<void> waitForRealIo(
  WidgetTester tester,
  Future<bool> Function() done,
) async {
  for (var round = 0; round < 50; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    if (await tester.runAsync(done) ?? false) return;
  }
  fail('the repository write did not land within 5 seconds');
}

/// Advances past route/dialog animations with timed pumps. The shell's feed
/// page sits on a real Isar watcher that never settles inside the fake-async
/// zone (its loading spinner animates forever), so pumpAndSettle would time
/// out here.
Future<void> settleSessionFlow(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump(const Duration(milliseconds: 400));
}
