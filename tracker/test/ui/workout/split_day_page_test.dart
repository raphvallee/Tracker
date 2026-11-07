// Split day page layout: exercise cards on the day's detail screen are
// separated by a fixed gap, and the gap is not added below the last card.

import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/ui/workout/widgets/split_day_page.dart';

import '../../../testing/test_helpers.dart';

void main() {
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
