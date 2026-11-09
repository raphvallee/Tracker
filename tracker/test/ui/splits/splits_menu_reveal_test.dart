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
import 'package:tracker/ui/splits/widgets/splits_page.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/isar_app_helpers.dart';
import '../../../testing/test_helpers.dart';
import '../../../testing/workout_helpers.dart';

void main() {
  setUpAll(initIsarCore);
  setUp(() => HydratedBloc.storage = InMemoryStorage());

  testWidgets('a split menu near the bottom scrolls clear of the nav bar', (
    tester,
  ) async {
    useTallWindow(tester);
    late TrackerRepository repo;
    await tester.runAsync(() async {
      final isar = await openTestIsar([
        ExerciseSchema,
        GymSchema,
        WorkoutSessionSchema,
        WorkoutSplitSchema,
      ], name: 'splits_menu_reveal');
      repo = TrackerRepository(isar);
      for (var i = 0; i < 9; i++) {
        await repo.splits.put(
          WorkoutSplit(
            title: 'Split $i',
            order: i,
            splitDays: [WorkoutSplitDay(title: 'Day $i')],
          ),
        );
      }
    });

    await pumpRealApp(tester, repo);
    await pumpUntil(tester, find.byType(FBottomNavigationBar));
    tester
        .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
        .onChange!(3);
    await pumpUntil(tester, find.text('Split 0'));

    final position = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(SplitsPage),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    final fullExtent = position.maxScrollExtent;
    expect(fullExtent, greaterThan(0), reason: 'the list must scroll');
    position.jumpTo(fullExtent);
    await pumpRounds(tester, 2);

    // The last split's menu opens below its button, past the list's end.
    await tester.tap(fButtonByTooltip('Split options').last);
    await pumpRounds(tester, 8);
    final navTop = tester.getTopLeft(find.byType(FBottomNavigationBar)).dy;
    final delete = find.ancestor(
      of: find.text('Delete'),
      matching: find.byType(FTile),
    );
    expect(tester.getBottomLeft(delete).dy, lessThanOrEqualTo(navTop - 8));
    expect(position.pixels, greaterThan(fullExtent), reason: 'made room');

    // Closed: the room shrinks away again.
    await tester.tapAt(const Offset(400, 40));
    await pumpRounds(tester, 8);
    expect(find.text('Delete'), findsNothing);
    expect(position.maxScrollExtent, moreOrLessEquals(fullExtent));
  });
}
