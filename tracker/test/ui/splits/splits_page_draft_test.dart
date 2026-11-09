// One Isar-backed case per file: each *_test.dart runs in its own
// flutter_tester process with a fresh libisar native worker pool (see
// docs/TESTING_ISAR_CI.md).

import 'package:flutter/material.dart';
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

  testWidgets('split edits wait in a draft until reviewed, or are discarded', (
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
      ], name: 'splits_page_draft');
      repo = TrackerRepository(isar);
      splitId = await repo.splits.put(
        WorkoutSplit(
          title: 'PPL',
          order: 0,
          splitDays: [
            WorkoutSplitDay(title: 'Push'),
            WorkoutSplitDay(title: 'Pull'),
          ],
        ),
      );
      await repo.splits.put(
        WorkoutSplit(
          title: 'Upper Lower',
          order: 1,
          splitDays: [WorkoutSplitDay(title: 'Upper')],
        ),
      );
    });

    final app = await pumpRealApp(tester, repo);
    await pumpUntil(tester, find.byType(FBottomNavigationBar));
    tester
        .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
        .onChange!(3);
    await pumpUntil(tester, find.text('Pull'));
    expect(find.text('2 days, not trained yet'), findsOneWidget);

    // Renaming edits the name in place and lands in the draft, not in the
    // database.
    await tester.tap(fButtonByTooltip('Split options').first);
    await pumpRounds(tester, 3);
    await tester.tap(find.text('Rename'));
    await pumpRounds(tester, 4);
    final field = find.byType(TextField);
    expect(field, findsOneWidget);
    expect(tester.testTextInput.isVisible, isTrue, reason: 'keyboard up');
    await tester.enterText(field, 'Push Pull Legs');
    await tester.tap(fButtonByTooltip('Done renaming'));
    await pumpUntil(tester, find.text('1 unsaved change'));
    await pumpRounds(tester, 4);
    expect(find.text('Push Pull Legs'), findsOneWidget);

    // Deleting a day asks first, then shows it struck through.
    await tester.tap(find.text('Pull'));
    await pumpUntil(tester, find.text('Day name'));
    await tester.tap(fButtonByTooltip('Day options'));
    await pumpRounds(tester, 3);
    await tester.tap(find.text('Delete day'));
    await pumpUntil(tester, find.text('Delete Pull?'));
    await pumpRounds(tester, 3);
    await tester.tap(find.text('Delete').last);
    await pumpUntil(tester, find.text('2 unsaved changes'));
    await pumpRounds(tester, 4);
    expect(find.text('Restore'), findsOneWidget);
    expect(find.text('Pull'), findsNothing, reason: 'struck through instead');

    await tester.tap(find.text('Restore'));
    await pumpUntil(tester, find.text('1 unsaved change'));
    await pumpRounds(tester, 4);
    expect(find.text('Pull'), findsOneWidget);

    // The other split becomes the current one.
    expect(find.text('Current'), findsOneWidget);
    await tester.tap(fButtonByTooltip('Split options').first);
    await pumpRounds(tester, 3);
    expect(find.text('Make current'), findsNothing, reason: 'already current');
    await tester.tap(fButtonByTooltip('Split options').first);
    await pumpRounds(tester, 3);

    // Discarding brings the saved split back.
    await tester.tap(find.text('Review'));
    await pumpUntil(tester, find.text('Review changes'));
    await pumpRounds(tester, 3);
    expect(find.text('Renamed split'), findsOneWidget);
    await tester.tap(find.text('Discard changes'));
    await pumpUntil(tester, find.text('Discard 1 change?'));
    await pumpRounds(tester, 3);
    await tester.tap(find.text('Discard'));
    await pumpWhile(tester, () => app.drafts.state.entries.isNotEmpty);
    await pumpRounds(tester, 6);
    expect(find.text('PPL'), findsOneWidget);
    expect(find.textContaining('unsaved change'), findsNothing);
    expect(app.drafts.state.entries, isEmpty);
    final saved = await tester.runAsync(() => repo.splits.getById(splitId));
    expect(saved!.title, 'PPL');
    expect(saved.splitDays.map((d) => d.title), ['Push', 'Pull']);
    expect(app.settings.state.currentSplitId, isNull);
  });
}
