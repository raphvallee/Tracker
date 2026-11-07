// Split day page header: the app bar carries "Split · Day", and the day
// description (when set) takes the place of the old duplicate header above the
// exercise list. An empty description renders nothing and adds no gap.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/ui/workout/widgets/split_day_page.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/test_helpers.dart';

void main() {
  setUp(() {
    // In-memory storage: the real HydratedStorage deadlocks the widget-test
    // fake-async zone once the app shell is pumped.
    HydratedBloc.storage = InMemoryStorage();
  });

  WorkoutSplitDay day({String description = ''}) => WorkoutSplitDay(
    title: 'Push Day',
    description: description,
    order: 0,
    exercises: [ExerciseItem(exerciseId: 1, order: 0, targetSets: 3)],
  );

  Future<void> pumpDay(WidgetTester tester, WorkoutSplitDay day) async {
    await pumpAppPage(
      tester,
      SplitDayPage(splitTitle: 'Push Pull Legs', day: day),
    );
  }

  testWidgets('app bar title is the split name and the day name', (
    tester,
  ) async {
    await pumpDay(tester, day(description: 'Chest, shoulders, triceps'));

    // Only the app bar carries the title: the old body header is gone.
    expect(find.text('Push Pull Legs · Push Day'), findsOneWidget);
    expect(find.text('Push Day'), findsNothing);
  });

  testWidgets('description sits above the exercise list when set', (
    tester,
  ) async {
    await pumpDay(tester, day(description: 'Chest, shoulders, triceps'));

    final description = find.text('Chest, shoulders, triceps');
    expect(description, findsOneWidget);
    expect(
      tester.getTopLeft(description).dy,
      lessThan(tester.getTopLeft(find.byType(FCard).first).dy),
    );
  });

  testWidgets('empty description renders no text above the exercise list', (
    tester,
  ) async {
    await pumpDay(tester, day());

    // The first card sits exactly at the content padding: no description text
    // and no leftover gap above it.
    final contentTop = tester
        .getTopLeft(
          find
              .descendant(
                of: find.byType(SliverToBoxAdapter),
                matching: find.byType(Padding),
              )
              .first,
        )
        .dy;
    final firstCardTop = tester.getTopLeft(find.byType(FCard).first).dy;
    expect(firstCardTop - contentTop, 16);
  });
}
