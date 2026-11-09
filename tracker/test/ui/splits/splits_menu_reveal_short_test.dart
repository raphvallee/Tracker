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

  testWidgets('a menu scrolls clear even when the splits fill less than a '
      'screen', (tester) async {
    useTallWindow(tester);
    late TrackerRepository repo;
    await tester.runAsync(() async {
      final isar = await openTestIsar([
        ExerciseSchema,
        GymSchema,
        WorkoutSessionSchema,
        WorkoutSplitSchema,
      ], name: 'splits_menu_reveal_short');
      repo = TrackerRepository(isar);
      // Splits without days: short sections, nothing to scroll.
      for (var i = 0; i < 3; i++) {
        await repo.splits.put(WorkoutSplit(title: 'Split $i', order: i));
      }
    });

    await pumpRealApp(tester, repo);
    await pumpUntil(tester, find.byType(FBottomNavigationBar));
    tester
        .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
        .onChange!(3);
    await pumpUntil(tester, find.text('Split 2'));

    // Read fresh each time: the scrollable swaps its position object when its
    // dependencies change.
    ScrollPosition position() => tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(SplitsPage),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    final menu = fButtonByTooltip('Split options').last;
    final delete = find.ancestor(
      of: find.text('Delete'),
      matching: find.byType(FTile),
    );
    Future<void> closeMenu() async {
      await tester.tapAt(const Offset(400, 40));
      await pumpRounds(tester, 8);
      expect(find.text('Delete'), findsNothing);
    }

    // How far below its button the last split's menu ends, measured while
    // the screen is tall enough for it.
    await tester.tap(menu);
    await pumpRounds(tester, 8);
    final reach =
        tester.getBottomLeft(delete).dy - tester.getBottomLeft(menu).dy;
    await closeMenu();

    // A screen just short enough that the menu would end 30px into the nav
    // bar, still on screen: it opens downwards, under the bar. Measured, not
    // hard-coded: text metrics vary by platform.
    final navAt = tester.getBottomLeft(menu).dy + reach - 30;
    final navTop = tester.getTopLeft(find.byType(FBottomNavigationBar)).dy;
    tester.view.physicalSize = Size(
      800,
      tester.view.physicalSize.height - (navTop - navAt),
    );
    await pumpRounds(tester, 2);
    expect(tester.getTopLeft(find.byType(FBottomNavigationBar)).dy, navAt);
    expect(position().maxScrollExtent, 0, reason: 'nothing to scroll yet');

    await tester.tap(menu);
    await pumpRounds(tester, 8);
    expect(tester.getBottomLeft(delete).dy, lessThanOrEqualTo(navAt - 8));
    expect(position().pixels, greaterThan(0), reason: 'scrolled up');

    await closeMenu();
    expect(position().maxScrollExtent, 0, reason: 'the room is gone');
  });
}
