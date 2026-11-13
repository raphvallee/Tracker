// Tests that touch real Isar IO live in their own files
// (session_edit_persist_test.dart, session_delete_persist_test.dart,
// session_edit_gym_*_test.dart): libisar's
// native worker pool is sized to the CPU count, so one process per Isar-heavy
// case keeps CI's 4-vCPU runners from wedging. See docs/TESTING_ISAR_CI.md.

import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/domain/models/number_entry.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/ui/core/ui/edit_sheet.dart';
import 'package:tracker/ui/core/ui/number_keypad.dart';
import 'package:tracker/ui/core/ui/relative_dates.dart';
import 'package:tracker/ui/history/widgets/session_edit_page.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/session_edit_helpers.dart';
import '../../../testing/test_helpers.dart';

void main() {
  setUp(() {
    // The app shell pumps HydratedCubits, which read storage at construction;
    // the real storage deadlocks the widget-test fake-async zone.
    HydratedBloc.storage = InMemoryStorage();
  });

  /// Pushes the editor onto a pumped app shell. The returned future completes
  /// with whatever the editor pops, so callers must not await it before
  /// saving or leaving.
  Future<SessionEditResult?> pushEditor(
    WidgetTester tester,
    WorkoutSession session,
  ) {
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    return navigator.push<SessionEditResult>(
      MaterialPageRoute<SessionEditResult>(
        builder: (_) => SessionEditPage(session: session),
      ),
    );
  }

  Future<void> openWorkingSet(WidgetTester tester) async {
    await tester.tap(find.textContaining('80 kg × 5'));
    await tester.pumpAndSettle();
  }

  /// The phone keyboard keeps the -/+ beside the open set's values.
  void useRowSteppers(WidgetTester tester) =>
      SettingsCubit.maybeOf(tester.element(find.byType(SessionEditPage)))!
          .setNumberEntry(NumberEntry.phoneKeyboard);

  Finder field(String label) => find.byWidgetPredicate(
    (w) => w is TextField && w.focusNode?.debugLabel == label,
  );

  Future<void> tapInDialog(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(of: find.byType(FDialog), matching: find.text(label)),
    );
    await tester.pumpAndSettle();
  }

  group('SessionEditPage', () {
    testWidgets('shows the workout fields in a card and every set', (
      tester,
    ) async {
      final session = pastSession();
      await pumpAppPage(tester, SessionEditPage(session: session));

      expect(find.text('Edit workout'), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Push'), findsOneWidget);
      expect(find.text('Gym'), findsOneWidget);
      expect(find.text('Other gym'), findsOneWidget);
      expect(find.text(dateTimeLabel(session.startTime)), findsOneWidget);
      // The end is on the same day: its time is enough.
      expect(find.text('10:00'), findsOneWidget);
      expect(find.text('Exercise 1'), findsOneWidget);
      expect(find.text('1 set, 1 warm-up'), findsOneWidget);
      expect(find.textContaining('80 kg × 5'), findsOneWidget);
      expect(find.textContaining('60 kg × 8'), findsOneWidget);
      expect(find.text('Add set'), findsOneWidget);
      expect(find.text('Add exercise'), findsOneWidget);
      // A draft with nothing changed has no save bar, and Delete hides in
      // the menu.
      expect(find.textContaining('unsaved change'), findsNothing);
      expect(find.text('Delete workout'), findsNothing);
    });

    testWidgets('a tap opens a set in place; a change shows what it was', (
      tester,
    ) async {
      await pumpAppPage(tester, SessionEditPage(session: pastSession()));
      useRowSteppers(tester);
      await openWorkingSet(tester);

      expect(find.text('Set 1'), findsOneWidget);
      expect(find.bySemanticsLabel('Increase weight'), findsOneWidget);
      expect(
        tester.widget<TextField>(field('edit set weight')).controller!.text,
        '80',
      );
      expect(find.textContaining('Was '), findsNothing);

      await tester.tap(find.bySemanticsLabel('Increase weight'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field('edit set weight')).controller!.text,
        '82.5',
      );
      expect(find.text('Edited'), findsOneWidget);
      expect(find.textContaining('Was 80 kg × 5'), findsOneWidget);
      expect(find.text('1 unsaved change'), findsOneWidget);

      // More edits to the same set are still one change.
      await tester.tap(find.bySemanticsLabel('Increase reps'));
      await tester.tap(find.bySemanticsLabel('Rate set 1 RPE 8'));
      await tester.pumpAndSettle();
      expect(find.text('1 unsaved change'), findsOneWidget);

      // Stepping back to the saved values undoes the change.
      await tester.tap(find.bySemanticsLabel('Decrease weight'));
      await tester.tap(find.bySemanticsLabel('Decrease reps'));
      await tester.tap(find.bySemanticsLabel('Rate set 1 RPE 8'));
      await tester.pumpAndSettle();
      expect(find.textContaining('unsaved change'), findsNothing);
      expect(find.text('Edited'), findsNothing);
    });

    testWidgets('with the steppers in the keypad, the keypad steps the set', (
      tester,
    ) async {
      await pumpAppPage(tester, SessionEditPage(session: pastSession()));
      SettingsCubit.maybeOf(tester.element(find.byType(SessionEditPage)))!
          .setNumberEntry(NumberEntry.keypadSteppers);
      await openWorkingSet(tester);
      expect(find.bySemanticsLabel('Increase weight'), findsNothing);

      await tester.tap(field('edit set weight'));
      await tester.pumpAndSettle();
      expect(find.byType(NumberKeypad), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Increase weight'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field('edit set weight')).controller!.text,
        '82.5',
      );
      expect(find.textContaining('Was 80 kg × 5'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.byType(NumberKeypad), findsNothing);
      expect(find.text('1 unsaved change'), findsOneWidget);
    });

    testWidgets('Discard drops every change', (tester) async {
      await pumpAppPage(tester, SessionEditPage(session: pastSession()));
      useRowSteppers(tester);
      await openWorkingSet(tester);
      await tester.tap(find.bySemanticsLabel('Increase weight'));
      await tester.tap(find.bySemanticsLabel('Set 1, tap for a warm-up'));
      await tester.pumpAndSettle();
      // Weight and type of one set: one change.
      expect(find.text('1 unsaved change'), findsOneWidget);

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.textContaining('unsaved change'), findsNothing);
      expect(find.textContaining('80 kg × 5'), findsOneWidget);
      expect(find.text('Edited'), findsNothing);
    });

    testWidgets('Save hands back the workout with what it does not edit', (
      tester,
    ) async {
      await pumpApp(tester);
      final saved = pushEditor(
        tester,
        pastSession(gymId: 4, splitId: 7, splitDayIndex: 2, rpe: 8),
      );
      await tester.pumpAndSettle();

      await renameWorkout(tester, '  Pull  ');
      expect(find.text('Pull'), findsOneWidget);
      expect(find.text('1 unsaved change'), findsOneWidget);
      await tapSaveBar(tester);

      final result = await saved;
      expect(result, isA<SessionSaved>());
      final session = (result! as SessionSaved).session;
      expect(session.title, 'Pull');
      expect(session.gymId, 4);
      expect(session.splitId, 7);
      expect(session.splitDayIndex, 2);
      expect(session.sets.first.rpe, 8);
      expect(session.sets.first.weight, 80);
      expect(session.sets.last.isWarmup, isTrue);
    });

    testWidgets('a set rated in place is saved with its rating', (
      tester,
    ) async {
      await pumpApp(tester);
      final saved = pushEditor(tester, pastSession());
      await tester.pumpAndSettle();
      await openWorkingSet(tester);
      await tester.tap(find.bySemanticsLabel('Rate set 1 RPE 9'));
      await tester.pumpAndSettle();
      expect(find.text('1 unsaved change'), findsOneWidget);
      await tapSaveBar(tester);

      final session = ((await saved)! as SessionSaved).session;
      expect(session.sets.first.rpe, 9);
    });

    testWidgets('the name cannot be left empty', (tester) async {
      await pumpAppPage(tester, SessionEditPage(session: pastSession()));
      await tester.tap(find.text('Name'));
      await tester.pumpAndSettle();
      final name = find.descendant(
        of: find.byType(EditSheet),
        matching: find.byType(EditableText),
      );
      await tester.enterText(name, '  ');
      await tester.tap(
        find.descendant(
          of: find.byType(EditSheet),
          matching: find.text('Save'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cannot be empty'), findsOneWidget);
      expect(find.byType(EditSheet), findsOneWidget);
    });

    testWidgets('a time opens in a sheet; closing it keeps the time', (
      tester,
    ) async {
      final session = pastSession();
      await pumpAppPage(tester, SessionEditPage(session: session));
      await tester.tap(find.text('Started'));
      await tester.pumpAndSettle();
      expect(find.byType(FDateTimePicker), findsOneWidget);
      // Swiping the sheet away keeps the time.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(EditSheet), findsNothing);
      expect(find.textContaining('unsaved change'), findsNothing);
    });

    testWidgets('swipes delete a set; Add set adds one after its exercise', (
      tester,
    ) async {
      await pumpAppPage(tester, SessionEditPage(session: pastSession()));

      Future<void> swipe(Finder target) async {
        // An open row lets the swipe through its content: the text itself
        // does not take the pointer.
        await tester.timedDrag(
          target,
          const Offset(-260, 0),
          const Duration(milliseconds: 250),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();
      }

      await swipe(find.textContaining('60 kg × 8'));
      expect(
        find.textContaining('60 kg × 8'),
        findsOneWidget,
        reason: 'one swipe never deletes',
      );
      await swipe(find.textContaining('60 kg × 8'));
      expect(find.textContaining('60 kg × 8'), findsNothing);
      expect(find.text('1 unsaved change'), findsOneWidget);
      expect(find.text('1 set'), findsOneWidget);

      await tester.tap(find.text('Add set'));
      await tester.pumpAndSettle();
      // The new set copies the exercise's last one and opens for editing.
      expect(find.text('New'), findsOneWidget);
      expect(find.text('Set 2'), findsOneWidget);
      expect(find.text('2 sets'), findsOneWidget);
      expect(find.text('2 unsaved changes'), findsOneWidget);
    });

    testWidgets('leaving with unsaved changes asks first', (tester) async {
      await pumpAppPage(tester, SessionEditPage(session: pastSession()));
      useRowSteppers(tester);
      await openWorkingSet(tester);
      await tester.tap(find.bySemanticsLabel('Increase reps'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(FLucideIcons.chevronLeft));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tapInDialog(tester, 'Discard');
      expect(find.text('Edit workout'), findsNothing);
    });

    testWidgets('Delete is in the menu only, and asks before it deletes', (
      tester,
    ) async {
      await pumpApp(tester);
      final session = pastSession();
      final result = pushEditor(tester, session);
      await tester.pumpAndSettle();

      await tester.tap(fButtonByTooltip('Workout options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete workout'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this workout?'), findsOneWidget);
      expect(
        find.text(
          'Push, ${shortDateLabel(session.startTime)}, with all its sets. '
          'This cannot be undone.',
        ),
        findsOneWidget,
      );
      await tapInDialog(tester, 'Cancel');
      expect(find.text('Edit workout'), findsOneWidget);

      await tester.tap(fButtonByTooltip('Workout options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete workout'));
      await tester.pumpAndSettle();
      await tapInDialog(tester, 'Delete');
      expect(await result, isA<SessionDeleted>());
    });
  });

  group('SessionEditPage typed values', () {
    Future<void> typeWeight(WidgetTester tester, String text) async {
      await openWorkingSet(tester);
      await tester.tap(field('edit set weight'));
      await tester.pumpAndSettle();
      // The keypad is the default number entry.
      expect(find.byType(NumberKeypad), findsOneWidget);
      await tester.enterText(field('edit set weight'), text);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
    }

    Future<void> typeReps(WidgetTester tester, String text) async {
      await openWorkingSet(tester);
      await tester.tap(field('edit set reps'));
      await tester.pumpAndSettle();
      await tester.enterText(field('edit set reps'), text);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
    }

    String weightText(WidgetTester tester) =>
        tester.widget<TextField>(field('edit set weight')).controller!.text;

    testWidgets('a negative weight asks for the assisted machine first', (
      tester,
    ) async {
      await pumpAppPage(tester, SessionEditPage(session: pastSession()));
      await typeWeight(tester, '-20');

      expect(find.text('Assisted machine?'), findsOneWidget);
      await tapInDialog(tester, 'Yes, log it');
      expect(find.textContaining('Was 80 kg × 5'), findsOneWidget);
      expect(weightText(tester), '-20');
    });

    testWidgets('a heavy weight asks; turned down, the value goes back', (
      tester,
    ) async {
      await pumpAppPage(tester, SessionEditPage(session: pastSession()));
      await typeWeight(tester, '600');

      expect(find.text("That's a lot of weight"), findsOneWidget);
      await tapInDialog(tester, 'Go back');
      expect(weightText(tester), '80');
      expect(find.textContaining('unsaved change'), findsNothing);
    });

    testWidgets('a heavy weight confirmed is kept', (tester) async {
      await pumpAppPage(tester, SessionEditPage(session: pastSession()));
      await typeWeight(tester, '600');
      await tapInDialog(tester, 'Use this weight');
      expect(weightText(tester), '600');
      expect(find.text('1 unsaved change'), findsOneWidget);
    });

    testWidgets('an out-of-range weight shows its error and is not kept', (
      tester,
    ) async {
      await pumpAppPage(tester, SessionEditPage(session: pastSession()));
      await typeWeight(tester, '10001');

      expect(find.text('Must be between -1000 and 10000'), findsOneWidget);
      expect(find.text("That's a lot of weight"), findsNothing);
      expect(find.textContaining('unsaved change'), findsNothing);
    });

    testWidgets('weight and reps keep two decimal places', (tester) async {
      await pumpAppPage(tester, SessionEditPage(session: pastSession()));
      await typeWeight(tester, '82.255');
      expect(weightText(tester), '82.25');
      await tester.tap(field('edit set reps'));
      await tester.pumpAndSettle();
      await tester.enterText(field('edit set reps'), '3.555');
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      // Closing the row shows the compact values.
      await tester.tap(find.text('Set 1'));
      await tester.pumpAndSettle();
      expect(find.textContaining('82.25 kg × 3.55'), findsOneWidget);
    });

    testWidgets('reps outside 0.1 to 2000 are refused', (tester) async {
      await pumpAppPage(tester, SessionEditPage(session: pastSession()));
      await typeReps(tester, '.05');
      expect(find.text('Must be between 0.1 and 2000'), findsOneWidget);
      expect(find.textContaining('unsaved change'), findsNothing);
    });

    testWidgets('many reps ask first', (tester) async {
      await pumpAppPage(tester, SessionEditPage(session: pastSession()));
      await typeReps(tester, '250');
      expect(find.text("That's a lot of reps"), findsOneWidget);
      await tapInDialog(tester, 'Use these reps');
      expect(find.text('1 unsaved change'), findsOneWidget);
    });
  });
}
