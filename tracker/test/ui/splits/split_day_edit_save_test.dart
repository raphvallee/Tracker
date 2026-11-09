// One Isar-backed case per file: each *_test.dart runs in its own
// flutter_tester process with a fresh libisar native worker pool (see
// docs/TESTING_ISAR_CI.md).

import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/muscle.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_split.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/isar_app_helpers.dart';
import '../../../testing/test_helpers.dart';
import '../../../testing/workout_helpers.dart';

void main() {
  setUpAll(initIsarCore);
  setUp(() => HydratedBloc.storage = InMemoryStorage());

  testWidgets('a set target edit is marked, reviewed and saved', (
    tester,
  ) async {
    useTallWindow(tester);
    late TrackerRepository repo;
    late int splitId;
    await tester.runAsync(() async {
      final isar = await openTestIsar([
        ExerciseSchema,
        GymSchema,
        WorkoutSessionSchema,
        WorkoutSplitSchema,
      ], name: 'split_day_edit_save');
      repo = TrackerRepository(isar);
      final bench = await repo.exercises.put(
        Exercise(
          title: 'Bench Press',
          primaryMuscle: [Muscle.chest],
          equipment: [Equipment.barbell],
        ),
      );
      splitId = await repo.splits.put(
        WorkoutSplit(
          title: 'PPL',
          order: 0,
          splitDays: [
            WorkoutSplitDay(
              title: 'Push',
              exercises: [
                ExerciseItem(
                  exerciseId: bench,
                  sets: [
                    for (var i = 0; i < 3; i++)
                      PlannedSet(order: i, minReps: 8, maxReps: 12),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    });

    final app = await pumpRealApp(tester, repo);
    await pumpUntil(tester, find.byType(FBottomNavigationBar));
    tester
        .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
        .onChange!(3);
    await pumpUntil(tester, find.text('Push'));
    expect(find.text('Splits'), findsWidgets);
    expect(find.text('Current'), findsOneWidget);
    expect(find.text('1 exercise, 3 sets'), findsOneWidget);
    expect(find.textContaining('Start'), findsNothing, reason: 'planning only');

    await tester.tap(find.text('Push'));
    await pumpUntil(tester, find.text('Bench Press'));
    expect(find.text('Day name'), findsOneWidget);
    expect(find.textContaining('unsaved change'), findsNothing);

    // Set 2 becomes 10 fixed reps.
    await tester.tap(labelled('Set 2, 8-12 reps'));
    await pumpUntil(tester, find.text('Bench Press, set 2'));
    await pumpRounds(tester, 4);
    expect(find.text('Push. Saved as 8-12 reps.'), findsOneWidget);
    await tester.tap(labelled('Fixed reps'));
    await pumpRounds(tester, 2);
    await tester.tap(labelled('More reps'));
    await tester.tap(labelled('More reps'));
    await pumpRounds(tester, 2);
    await tester.tap(find.text('Done'));
    await pumpUntil(tester, find.text('1 unsaved change'));
    await pumpRounds(tester, 3);

    expect(labelled('Set 2, 10 reps'), findsOneWidget);
    expect(find.text('Edited'), findsOneWidget);
    expect(find.text('Kept even if the app closes'), findsOneWidget);
    expect(app.drafts.state.entries.containsKey(splitId), isTrue);

    // Set 1 becomes a warm-up: "Use for all" now reaches its type only.
    await tester.tap(labelled('Set 1, 8-12 reps'));
    await pumpUntil(tester, find.text('Bench Press, set 1'));
    await pumpRounds(tester, 4);
    expect(find.text('Use for all 3 sets'), findsOneWidget);
    await tester.tap(find.text('Warm-up set'));
    await pumpRounds(tester, 2);
    expect(find.text('Use for all 3 sets'), findsNothing);
    expect(find.text('Use for all 2 working sets'), findsNothing);
    await tester.tap(find.text('Done'));
    await pumpUntil(tester, find.text('2 unsaved changes'));
    await pumpRounds(tester, 3);
    expect(labelled('Set 1, 8-12 warm-up reps'), findsOneWidget);
    expect(find.text('warm-up'), findsOneWidget);
    await tester.tap(labelled('Set 2, 10 reps'));
    await pumpUntil(tester, find.text('Bench Press, set 2'));
    await pumpRounds(tester, 4);
    expect(find.text('Use for all 2 working sets'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await pumpWhile(
      tester,
      () => find.text('Bench Press, set 2').evaluate().isNotEmpty,
    );

    await tester.tap(find.text('Review and save'));
    await pumpUntil(tester, find.text('Review changes'));
    await pumpRounds(tester, 4);
    expect(find.text('Bench Press, set 2'), findsOneWidget);
    expect(find.text('Bench Press, set 1'), findsOneWidget);
    expect(find.text('8-12 reps'), findsNWidgets(2));
    expect(find.text('8-12 warm-up reps'), findsOneWidget);
    expect(find.text('10 reps'), findsOneWidget);
    await tester.tap(find.text('Save 2 changes'));
    await pumpWhile(tester, () => app.drafts.state.entries.isNotEmpty);
    await pumpWhile(
      tester,
      () => find.text('Review changes').evaluate().isNotEmpty,
    );

    expect(app.drafts.state.entries, isEmpty);
    await pumpRounds(tester, 3);
    expect(find.textContaining('unsaved change'), findsNothing);
    final saved = await tester.runAsync(() => repo.splits.getById(splitId));
    final sets = saved!.splitDays.single.exercises.single.sets;
    expect(sets.map((s) => (s.minReps, s.maxReps, s.isWarmup)), [
      (8, 12, true),
      (10, null, false),
      (8, 12, false),
    ]);
  });
}
