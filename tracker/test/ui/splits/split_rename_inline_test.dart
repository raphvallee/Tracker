// One Isar-backed case per file: each *_test.dart runs in its own
// flutter_tester process with a fresh libisar native worker pool (see
// docs/TESTING_ISAR_CI.md).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('rename edits the name in place, with the keyboard up', (
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
      ], name: 'split_rename_inline');
      repo = TrackerRepository(isar);
      await repo.splits.put(
        WorkoutSplit(
          title: 'PPL',
          order: 0,
          splitDays: [WorkoutSplitDay(title: 'Push')],
        ),
      );
    });

    final app = await pumpRealApp(tester, repo);
    await pumpUntil(tester, find.byType(FBottomNavigationBar));
    tester
        .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
        .onChange!(3);
    await pumpUntil(tester, find.text('PPL'));
    final name = tester.getTopLeft(find.text('PPL'));

    Future<void> rename() async {
      await tester.tap(fButtonByTooltip('Split options').first);
      await pumpRounds(tester, 3);
      await tester.tap(find.text('Rename'));
      await pumpRounds(tester, 4);
    }

    final field = find.byType(EditableText);
    await rename();
    expect(field, findsOneWidget);
    final at = tester.getTopLeft(field);
    expect(at.dx, moreOrLessEquals(name.dx, epsilon: 0.5));
    expect(at.dy, moreOrLessEquals(name.dy, epsilon: 0.5), reason: 'in place');
    expect(tester.testTextInput.isVisible, isTrue, reason: 'keyboard up');
    expect(
      tester.widget<EditableText>(field).controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 3),
      reason: 'the name is selected, typing replaces it',
    );
    expect(fButtonByTooltip('Done renaming'), findsOneWidget);

    // A blank name keeps the old one.
    await tester.enterText(field, '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await pumpRounds(tester, 4);
    expect(field, findsNothing);
    expect(find.text('PPL'), findsOneWidget);
    expect(app.drafts.state.entries, isEmpty);

    // Escape leaves it as it was.
    await rename();
    await tester.enterText(field, 'Nope');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await pumpRounds(tester, 4);
    expect(find.text('PPL'), findsOneWidget);
    expect(app.drafts.state.entries, isEmpty);

    // The keyboard's Done saves it to the draft.
    await rename();
    await tester.enterText(field, 'Push Pull Legs');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await pumpUntil(tester, find.text('1 unsaved change'));
    expect(find.text('Push Pull Legs'), findsOneWidget);
    expect(field, findsNothing);
    expect(
      app.drafts.state.entries.values.single.draft.title,
      'Push Pull Legs',
    );
  });
}
