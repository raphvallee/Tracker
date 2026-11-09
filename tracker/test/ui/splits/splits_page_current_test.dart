// One Isar-backed case per file: each *_test.dart runs in its own
// flutter_tester process with a fresh libisar native worker pool (see
// docs/TESTING_ISAR_CI.md).

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

  testWidgets('a split made current slides to the top, the old one below', (
    tester,
  ) async {
    useTallWindow(tester);
    late TrackerRepository repo;
    final ids = <String, int>{};
    await tester.runAsync(() async {
      final isar = await openTestIsar([
        ExerciseSchema,
        GymSchema,
        WorkoutSessionSchema,
        WorkoutSplitSchema,
      ], name: 'splits_page_current');
      repo = TrackerRepository(isar);
      for (final (i, title) in ['PPL', 'Upper Lower', 'Full Body'].indexed) {
        ids[title] = await repo.splits.put(
          WorkoutSplit(
            title: title,
            order: i,
            splitDays: [WorkoutSplitDay(title: '$title day')],
          ),
        );
      }
      // Upper Lower was trained last week: it lists before Full Body.
      await repo.sessions.put(
        WorkoutSession(
          title: 'Upper Lower · Upper Lower day',
          startTime: DateTime.now().subtract(const Duration(days: 7)),
          splitId: ids['Upper Lower'],
          splitDayIndex: 0,
        ),
      );
    });

    final app = await pumpRealApp(tester, repo);
    await pumpUntil(tester, find.byType(FBottomNavigationBar));
    tester
        .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
        .onChange!(3);
    await pumpUntil(tester, find.text('Full Body'));

    double top(String title) => tester.getTopLeft(find.text(title)).dy;
    List<String> order() {
      final titles = ['PPL', 'Upper Lower', 'Full Body'];
      return titles..sort((a, b) => top(a).compareTo(top(b)));
    }

    // Upper Lower is current: the most recently trained.
    expect(order(), ['Upper Lower', 'PPL', 'Full Body']);
    final startTop = top('Upper Lower');
    final fullBodyTop = top('Full Body');

    await tester.tap(fButtonByTooltip('Split options').at(2));
    await pumpRounds(tester, 3);
    await tester.tap(find.text('Make current'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      top('Full Body'),
      inExclusiveRange(startTop, fullBodyTop),
      reason: 'sliding up',
    );

    await pumpRounds(tester, 6);
    expect(order(), ['Full Body', 'Upper Lower', 'PPL']);
    expect(top('Full Body'), startTop);
    expect(app.settings.state.currentSplitId, ids['Full Body']);
    expect(app.settings.state.splitsUsedAt.keys, [ids['Upper Lower']]);
    final badge = find.ancestor(
      of: find.text('Current'),
      matching: find.byType(FBadge),
    );
    expect(tester.getTopLeft(badge).dy, greaterThan(top('Full Body')));
    expect(tester.getTopLeft(badge).dy, lessThan(top('Upper Lower')));

    // Back to PPL: Full Body, current until now, lists right below it.
    await tester.tap(fButtonByTooltip('Split options').at(2));
    await pumpRounds(tester, 3);
    await tester.tap(find.text('Make current'));
    await pumpRounds(tester, 6);
    expect(order(), ['PPL', 'Full Body', 'Upper Lower']);
    expect(app.settings.state.currentSplitId, ids['PPL']);
  });
}
