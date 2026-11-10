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
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/workout/widgets/start_view.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/isar_app_helpers.dart';
import '../../../testing/test_helpers.dart';
import '../../../testing/workout_helpers.dart';

/// The header's Empty workout button, while it is on the page.
Finder headerButton() => find.descendant(
  of: find.byType(CustomAppBar),
  matching: find.text('Empty workout'),
);

Finder headerTitle() => find.descendant(
  of: find.byType(CustomAppBar),
  matching: find.text('Workout'),
);

void main() {
  setUpAll(initIsarCore);
  setUp(() => HydratedBloc.storage = InMemoryStorage());

  testWidgets('a plan too long for the screen puts Empty workout in the '
      'header until the row under it scrolls into view', (tester) async {
    useTallWindow(tester);
    late TrackerRepository repo;
    await tester.runAsync(() async {
      final isar = await openTestIsar([
        ExerciseSchema,
        GymSchema,
        WorkoutSessionSchema,
        WorkoutSplitSchema,
      ], name: 'workout_empty_header');
      repo = TrackerRepository(isar);
      final ids = [
        for (var i = 0; i < 8; i++)
          await repo.exercises.put(
            Exercise(
              title: 'Lift ${i + 1}',
              primaryMuscle: [Muscle.chest],
              equipment: [Equipment.barbell],
            ),
          ),
      ];
      await repo.gyms.put(Gym(name: 'Iron Temple', isPrimary: true, order: 0));
      WorkoutSplitDay day(String title, int exercises) => WorkoutSplitDay(
        title: title,
        exercises: [
          for (final id in ids.take(exercises))
            ExerciseItem(
              exerciseId: id,
              sets: [
                for (var i = 0; i < 3; i++)
                  PlannedSet(order: i, minReps: 8, maxReps: 12),
              ],
            ),
        ],
      );
      await repo.splits.put(
        WorkoutSplit(
          title: 'Upper Lower',
          order: 0,
          splitDays: [day('Upper', 8), day('Lower', 7)],
        ),
      );
    });

    final app = await pumpRealApp(tester, repo);
    await pumpUntil(tester, find.byType(FBottomNavigationBar));
    tester
        .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
        .onChange!(2);
    await pumpUntil(tester, find.text('Start Upper'));
    await pumpRounds(tester);

    // A tall window fits the whole plan: the row is in sight.
    expect(find.text('Pick exercises as you go'), findsOneWidget);
    expect(headerButton(), findsNothing);

    // On a small phone the row drops below the fold: the header offers it.
    tester.view.physicalSize = const Size(320, 568);
    await pumpRounds(tester);
    expect(headerButton().hitTestable(), findsOneWidget);
    final title = tester.getRect(headerTitle());
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Empty workout'), findsOneWidget);

    // Another long day: the button stays put, frame after frame.
    await tester.tap(find.text('Lower'));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(headerButton().hitTestable(), findsOneWidget);
    }
    await pumpUntil(tester, find.text('Start Lower'));
    expect(headerButton().hitTestable(), findsOneWidget);

    // Scrolled into view, the row takes over: the header button leaves the
    // page, the semantics tree and hit testing.
    final page = find
        .descendant(
          of: find.byType(StartView),
          matching: find.byType(Scrollable),
        )
        .first;
    final position = tester.state<ScrollableState>(page).position;
    position.jumpTo(position.maxScrollExtent);
    await pumpRounds(tester);
    expect(headerButton(), findsNothing);
    expect(find.bySemanticsLabel('Empty workout'), findsNothing);
    expect(find.text('Empty workout').hitTestable(), findsOneWidget);
    expect(
      tester.getRect(headerTitle()),
      title,
      reason: 'the title kept still',
    );

    // Back at the top, it returns; a tap starts a workout without a plan.
    position.jumpTo(0);
    await pumpRounds(tester);
    expect(headerButton().hitTestable(), findsOneWidget);
    semantics.dispose();
    await tester.tap(headerButton());
    await pumpUntil(tester, find.text('Free workout'));
    expect(app.workout.state.isInProgress, isTrue);
    expect(app.workout.state.planTitle, isNull);
    expect(app.workout.state.gymName, 'Iron Temple');
  });
}
