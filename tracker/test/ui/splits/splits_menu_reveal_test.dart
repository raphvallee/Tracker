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
    final fullExtent = position().maxScrollExtent;
    expect(fullExtent, greaterThan(0), reason: 'the list must scroll');
    final navTop = tester.getTopLeft(find.byType(FBottomNavigationBar)).dy;
    final delete = find.ancestor(
      of: find.text('Delete'),
      matching: find.byType(FTile),
    );
    Finder button(int split) => fButtonByTooltip('Split options').at(split);

    Future<void> closeMenu() async {
      await tester.tapAt(const Offset(400, 40));
      await pumpRounds(tester, 8);
      expect(find.text('Delete'), findsNothing);
    }

    // How far below its button a menu ends, measured where it fits, on a
    // split that is not current (the current one has no Make current row).
    await tester.tap(button(1));
    await pumpRounds(tester, 8);
    expect(find.text('Make current'), findsOneWidget);
    final reach =
        tester.getBottomLeft(delete).dy - tester.getBottomLeft(button(1)).dy;
    expect(position().pixels, 0, reason: 'nothing to reveal up there');
    await closeMenu();

    // A split scrolled so its menu would end 30px into the nav bar: still
    // on screen, so the menu opens downwards, under the bar. Picked with
    // list to spare below it, so revealing the menu is a plain scroll (the
    // short-list test covers making room). Measured, not hard-coded: text
    // metrics vary by platform.
    double shiftFor(int split) =>
        tester.getBottomLeft(button(split)).dy + reach - (navTop + 30);
    final split = [for (var i = 8; i > 1; i--) i]
        .firstWhere((i) => shiftFor(i) >= 0 && shiftFor(i) + 100 <= fullExtent);
    final shift = shiftFor(split);
    position().jumpTo(shift);
    await pumpRounds(tester, 2);
    expect(tester.getBottomLeft(button(split)).dy + reach, navTop + 30);

    await tester.tap(button(split));
    await pumpRounds(tester, 8);
    expect(tester.getBottomLeft(delete).dy, lessThanOrEqualTo(navTop - 8));
    expect(position().pixels, greaterThan(shift), reason: 'scrolled it clear');
    expect(
      position().maxScrollExtent,
      fullExtent,
      reason: 'the list had the room already',
    );

    await closeMenu();
    expect(position().maxScrollExtent, moreOrLessEquals(fullExtent));
  });
}
