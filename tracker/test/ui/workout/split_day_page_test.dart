// Split day page layout: exercise cards on the day's detail screen are
// separated by a fixed gap, and the gap is not added below the last card.

import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/ui/core/ui/swipeable_text.dart';
import 'package:tracker/ui/workout/widgets/split_day_page.dart';

import '../../../testing/test_helpers.dart';

void main() {
  testWidgets('exercises show their set count and no rep targets', (
    tester,
  ) async {
    final day = WorkoutSplitDay(
      title: 'Push Day',
      description: '',
      order: 0,
      exercises: [
        ExerciseItem(
          exerciseId: 1,
          order: 0,
          sets: [
            PlannedSet(order: 0, minReps: 10),
            PlannedSet(order: 1, minReps: 8, maxReps: 12),
            PlannedSet(order: 2, minReps: 8, maxReps: 12),
          ],
        ),
        ExerciseItem(
          exerciseId: 2,
          order: 1,
          sets: [PlannedSet(order: 0, minReps: 5)],
        ),
        // Legacy item saved before planned sets existed.
        ExerciseItem(exerciseId: 3, order: 2, targetSets: 4, targetReps: 6),
      ],
    );
    await pumpAppPage(tester, SplitDayPage(splitTitle: 'PPL', day: day));

    // Orders are 1, 2, 3 and set counts are 3, 1, 4.
    expect(find.text('1'), findsNWidgets(2));
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsNWidgets(2));
    expect(find.text('4'), findsOneWidget);
    expect(find.text('sets'), findsNWidgets(2));
    expect(find.text('set'), findsOneWidget);
    expect(find.textContaining('8-12'), findsNothing);
    expect(find.textContaining('reps'), findsNothing);
  });

  testWidgets('heading shows only the split title', (tester) async {
    final day = WorkoutSplitDay(
      title: 'Push Day',
      description: '',
      order: 0,
      exercises: [ExerciseItem(exerciseId: 1, order: 0)],
    );
    await pumpAppPage(tester, SplitDayPage(splitTitle: 'PPL', day: day));

    expect(find.text('PPL'), findsOneWidget);
    expect(find.textContaining('PPL ·'), findsNothing);
    // The day title stays in the app bar only.
    expect(find.text('Push Day'), findsOneWidget);
  });

  testWidgets('order sits left of the name and set count right of it', (
    tester,
  ) async {
    final day = WorkoutSplitDay(
      title: 'Push Day',
      description: '',
      order: 0,
      exercises: [
        ExerciseItem(
          exerciseId: 7,
          order: 0,
          sets: [for (var i = 0; i < 5; i++) PlannedSet(order: i, minReps: 8)],
        ),
      ],
    );
    await pumpAppPage(tester, SplitDayPage(splitTitle: 'PPL', day: day));

    expect(
      find.ancestor(
        of: find.text('Exercise 7'),
        matching: find.byType(SwipeableText),
      ),
      findsOneWidget,
    );
    final order = tester.getCenter(find.text('1')).dx;
    final name = tester.getCenter(find.text('Exercise 7')).dx;
    final count = tester.getCenter(find.text('5')).dx;
    expect(order, lessThan(name));
    expect(name, lessThan(count));
  });

  testWidgets('exercises without any plan leave the count blank', (
    tester,
  ) async {
    final day = WorkoutSplitDay(
      title: 'Push Day',
      description: '',
      order: 0,
      exercises: [ExerciseItem(exerciseId: 1, order: 0)],
    );
    await pumpAppPage(tester, SplitDayPage(splitTitle: 'PPL', day: day));

    expect(find.text('Exercise 1'), findsOneWidget);
    expect(find.text('sets'), findsNothing);
    expect(find.text('set'), findsNothing);
  });

  testWidgets('exercise cards on the split day page are 8px apart', (
    tester,
  ) async {
    final day = WorkoutSplitDay(
      title: 'Push Day',
      description: '',
      order: 0,
      exercises: [
        for (var i = 0; i < 3; i++) ExerciseItem(exerciseId: i + 1, order: i),
      ],
    );
    await pumpAppPage(tester, SplitDayPage(splitTitle: 'PPL', day: day));

    final cards = find.descendant(
      of: find.byType(SplitDayPage),
      matching: find.byType(FCard),
    );
    expect(cards, findsNWidgets(3));
    for (var i = 0; i < 2; i++) {
      final previous = tester.getRect(cards.at(i));
      final next = tester.getRect(cards.at(i + 1));
      expect(next.top - previous.bottom, 8.0);
    }
  });
}
