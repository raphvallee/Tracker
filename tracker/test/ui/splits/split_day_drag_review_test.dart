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
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_split.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/isar_app_helpers.dart';
import '../../../testing/test_helpers.dart';
import '../../../testing/workout_helpers.dart';

void main() {
  setUpAll(initIsarCore);
  setUp(() => HydratedBloc.storage = InMemoryStorage());

  testWidgets('a day dragged up is the one marked and reviewed as moved', (
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
      ], name: 'split_day_drag_review');
      repo = TrackerRepository(isar);
      splitId = await repo.splits.put(
        WorkoutSplit(
          title: 'PPL',
          order: 0,
          splitDays: [
            WorkoutSplitDay(title: 'Push'),
            WorkoutSplitDay(title: 'Pull'),
            WorkoutSplitDay(title: 'Legs'),
          ],
        ),
      );
    });

    final app = await pumpRealApp(tester, repo);
    await pumpUntil(tester, find.byType(FBottomNavigationBar));
    tester
        .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
        .onChange!(3);
    await pumpUntil(tester, find.text('Legs'));

    // Legs, by its grip, up past Pull.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(FLucideIcons.gripVertical).at(2)),
    );
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(0, -10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await pumpUntil(tester, find.text('1 unsaved change'));
    await pumpRounds(tester, 3);

    final draft = app.drafts.state.entries[splitId]!.draft;
    expect(draft.days.map((d) => d.title), ['Push', 'Legs', 'Pull']);
    Finder tagOf(String day) => find.descendant(
      of: find.ancestor(of: find.text(day), matching: find.byType(Wrap)).first,
      matching: find.text('Edited'),
    );
    expect(tagOf('Legs'), findsOneWidget);
    expect(tagOf('Pull'), findsNothing);

    await tester.tap(find.text('Review'));
    await pumpUntil(tester, find.text('Review changes'));
    await pumpRounds(tester, 3);
    expect(find.text('Moved Legs'), findsOneWidget);
    expect(find.text('Moved Pull'), findsNothing);
    expect(find.text('3rd'), findsOneWidget);
    expect(find.text('2nd'), findsOneWidget);
  });
}
