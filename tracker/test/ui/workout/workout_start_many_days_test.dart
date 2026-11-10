// One Isar-backed case per file: each *_test.dart runs in its own
// flutter_tester process with a fresh libisar native worker pool (see
// docs/TESTING_ISAR_CI.md).

import 'package:flutter/widgets.dart';
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

  testWidgets('five days scroll to the one up next; another split is a '
      'sheet away', (tester) async {
    // A small phone: three days fit in the row, with a sliver of a fourth.
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late TrackerRepository repo;
    await tester.runAsync(() async {
      final isar = await openTestIsar([
        ExerciseSchema,
        GymSchema,
        WorkoutSessionSchema,
        WorkoutSplitSchema,
      ], name: 'workout_start_many_days');
      repo = TrackerRepository(isar);
      final bench = await repo.exercises.put(
        Exercise(
          title: 'Bench Press',
          primaryMuscle: [Muscle.chest],
          equipment: [Equipment.barbell],
        ),
      );
      await repo.gyms.put(Gym(name: 'Iron Temple', isPrimary: true, order: 0));
      WorkoutSplitDay day(String title) => WorkoutSplitDay(
        title: title,
        exercises: [
          ExerciseItem(
            exerciseId: bench,
            sets: [
              for (var i = 0; i < 3; i++)
                PlannedSet(order: i, minReps: 8, maxReps: 12),
            ],
          ),
        ],
      );
      final split = WorkoutSplit(
        title: 'PPLUL',
        order: 0,
        splitDays: [
          for (final title in ['Push', 'Pull', 'Legs', 'Upper', 'Lower'])
            day(title),
        ],
      );
      await repo.splits.put(split);
      await repo.splits.put(
        WorkoutSplit(title: 'Full Body', order: 1, splitDays: [day('Day A')]),
      );
      // Legs was trained yesterday: Upper is due.
      await repo.sessions.put(
        WorkoutSession(
          title: 'PPLUL · Legs',
          startTime: DateTime.now().subtract(const Duration(days: 1)),
          splitId: split.id,
          splitDayIndex: 2,
        ),
      );
    });

    final app = await pumpRealApp(tester, repo);
    await pumpUntil(tester, find.byType(FBottomNavigationBar));
    tester
        .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
        .onChange!(2);
    await pumpUntil(tester, find.text('Start Upper'));
    await tester.pump();

    // The row opened scrolled to Upper: Push is off the left edge.
    final upper = tester.getRect(labelled('Upper, up next'));
    expect(upper.left, greaterThanOrEqualTo(0));
    expect(upper.right, lessThanOrEqualTo(320));
    expect(tester.getRect(labelled('Push, not done yet')).right, lessThan(0));

    await tester.tap(labelled('Lower, not done yet'));
    await pumpUntil(tester, find.text('Start Lower'));

    // The split's name opens the split sheet; picking one shows its days
    // here without making it the current split.
    await tester.tap(labelled('Split: PPLUL. Train from another split'));
    await pumpUntil(tester, find.text('Train from'));
    expect(find.text('Current split, 5 days'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Full Body'));
    await pumpUntil(tester, find.text('Start Day A'));
    expect(find.text('Upper'), findsNothing);
    expect(app.settings.state.currentSplitId, isNull);
  });
}
