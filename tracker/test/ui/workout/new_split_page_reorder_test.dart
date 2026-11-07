// Split editor day reordering, widget-only (no Isar): dragging a day's grip
// reorders the list, the draft becomes dirty (discard guard fires), a day
// opened after a reorder is the right one, and a save hands back the days in
// their new order. Persistence is covered in new_split_page_reorder_persist_test.dart.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/ui/workout/widgets/new_split_page.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/test_helpers.dart';

void main() {
  setUp(() {
    HydratedBloc.storage = InMemoryStorage();
  });

  WorkoutSplit threeDaySplit() => WorkoutSplit(
    title: 'Push Pull Legs',
    splitDays: [
      WorkoutSplitDay(title: 'Push', order: 0),
      WorkoutSplitDay(title: 'Pull', order: 1),
      WorkoutSplitDay(title: 'Legs', order: 2),
    ],
  );

  Future<WorkoutSplit?> pushSplitEditor(
    WidgetTester tester,
    WorkoutSplit split,
  ) {
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    return navigator.push<WorkoutSplit>(
      MaterialPageRoute<WorkoutSplit>(
        builder: (_) => SplitEditorPage(split: split),
      ),
    );
  }

  /// Day rows inside the split editor, in list order.
  Finder dayTitle(String title) => find.descendant(
    of: find.byType(SplitEditorPage),
    matching: find.text(title),
  );

  /// Drags the grip of the day at [index] by [dy] pixels (negative = up),
  /// in small steps so the reorder list sees a real drag gesture.
  Future<void> dragDay(WidgetTester tester, int index, double dy) async {
    final grip = find.byIcon(FLucideIcons.gripHorizontal).at(index);
    final gesture = await tester.startGesture(tester.getCenter(grip));
    const steps = 10;
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(Offset(0, dy / steps));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('dragging a day grip moves the day up the list', (tester) async {
    await pumpApp(tester);
    unawaited(pushSplitEditor(tester, threeDaySplit()));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(dayTitle('Pull')).dy,
      greaterThan(tester.getTopLeft(dayTitle('Push')).dy),
    );

    await dragDay(tester, 1, -120);

    expect(
      tester.getTopLeft(dayTitle('Pull')).dy,
      lessThan(tester.getTopLeft(dayTitle('Push')).dy),
    );
  });

  testWidgets('a reorder marks the draft dirty and the discard guard fires', (
    tester,
  ) async {
    await pumpApp(tester);
    unawaited(pushSplitEditor(tester, threeDaySplit()));
    await tester.pumpAndSettle();

    await dragDay(tester, 1, -120);

    await tester.tap(find.byIcon(FLucideIcons.chevronLeft));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('moving a day back to its saved position is clean again', (
    tester,
  ) async {
    await pumpApp(tester);
    final result = pushSplitEditor(tester, threeDaySplit());
    await tester.pumpAndSettle();

    await dragDay(tester, 1, -120);
    await dragDay(tester, 0, 80);

    // Back in the saved order: back pops without a confirmation.
    await tester.tap(find.byIcon(FLucideIcons.chevronLeft));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(await result, isNull);
  });

  testWidgets('a day opened after a reorder is the day shown in that row', (
    tester,
  ) async {
    await pumpApp(tester);
    unawaited(pushSplitEditor(tester, threeDaySplit()));
    await tester.pumpAndSettle();

    await dragDay(tester, 2, -200);
    // Legs is now first; tapping the top row must open Legs.
    expect(
      tester.getTopLeft(dayTitle('Legs')).dy,
      lessThan(tester.getTopLeft(dayTitle('Push')).dy),
    );

    await tester.tap(dayTitle('Legs'));
    await tester.pumpAndSettle();

    final dayName = tester.widget<EditableText>(
      find
          .descendant(
            of: find.widgetWithText(FTextField, 'Day name'),
            matching: find.byType(EditableText),
          )
          .first,
    );
    expect(dayName.controller.text, 'Legs');
  });

  testWidgets('save hands back the days in the reordered order', (
    tester,
  ) async {
    await pumpApp(tester);
    final result = pushSplitEditor(tester, threeDaySplit());
    await tester.pumpAndSettle();

    await dragDay(tester, 1, -120);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await result;
    expect(saved, isNotNull);
    expect(saved!.splitDays.map((d) => d.title), ['Pull', 'Push', 'Legs']);
    expect(saved.splitDays.map((d) => d.order), [0, 1, 2]);
  });
}
