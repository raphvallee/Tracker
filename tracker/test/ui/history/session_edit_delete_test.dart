// History edit/delete widget tests (lib/ui/history/). The detail page surfaces
// Edit/Delete, and the editor renders prefilled fields and edits a set through
// the dialog. Tests that touch real Isar IO live in their own files
// (session_edit_persist_test.dart, session_delete_persist_test.dart,
// session_edit_delete_repo_test.dart): libisar's native worker pool is sized to
// the CPU count, so one process per Isar-heavy case keeps CI's 4-vCPU runners
// from wedging. See docs/TESTING_ISAR_CI.md.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/ui/history/widgets/session_detail_page.dart';
import 'package:tracker/ui/history/widgets/session_edit_page.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/session_edit_helpers.dart';
import '../../../testing/test_helpers.dart';

void main() {
  setUpAll(initIsarCore);

  setUp(() {
    // The app shell pumps HydratedCubits, which read storage at construction;
    // the real storage deadlocks the widget-test fake-async zone.
    HydratedBloc.storage = InMemoryStorage();
  });

  group('SessionDetailPage actions', () {
    testWidgets('offers Edit and Delete for a past session', (tester) async {
      await pumpAppPage(
        tester,
        SessionDetailPage(session: pastSession(), gymName: 'Home'),
      );

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete session'), findsOneWidget);
    });
  });

  group('SessionEditPage', () {
    testWidgets('renders prefilled session fields and sets', (tester) async {
      await pumpAppPage(tester, SessionEditPage(session: pastSession()));

      expect(find.text('Edit session'), findsOneWidget); // app bar title
      expect(find.text('Save'), findsOneWidget); // app bar action
      expect(find.text('No gym'), findsOneWidget); // no repository in scope
      expect(find.text('80 kg × 5'), findsOneWidget);
      expect(find.text('60 kg × 8'), findsOneWidget);
      final title = find
          .descendant(
            of: find.byType(FTextField),
            matching: find.byType(EditableText),
          )
          .first;
      expect(tester.widget<EditableText>(title).controller.text, 'Push');
    });

    testWidgets('editing a set through the dialog updates the draft row', (
      tester,
    ) async {
      await pumpAppPage(tester, SessionEditPage(session: pastSession()));

      // Tap the 80 kg × 5 row to open the per-set editor.
      await tester.tap(find.text('80 kg × 5'));
      await tester.pumpAndSettle();
      expect(find.text('Edit set'), findsOneWidget);

      // Weight and reps arrive prefilled; overwrite them and make warm-up.
      final fields = find.descendant(
        of: find.byType(FDialog),
        matching: find.byType(EditableText),
      );
      expect(fields, findsNWidgets(2));
      expect(tester.widget<EditableText>(fields.first).controller.text, '80');
      expect(tester.widget<EditableText>(fields.last).controller.text, '5');
      await tester.enterText(fields.first, '82.5');
      await tester.enterText(fields.last, '3');
      await tester.tap(find.text('Warm-up'));
      await tester.tap(
        find.descendant(of: find.byType(FDialog), matching: find.text('Save')),
      );
      await tester.pumpAndSettle();

      // The draft row re-renders with the new values (kg is the default
      // test unit) and the W chip count follows the toggled type.
      expect(find.text('82.5 kg × 3'), findsOneWidget);
      expect(find.text('80 kg × 5'), findsNothing);
      expect(find.text('W'), findsNWidgets(2));
      expect(find.text('S'), findsNothing);
    });

    testWidgets('Save pops back out of the editor', (tester) async {
      await pumpAppPage(tester, SessionEditPage(session: pastSession()));

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Edit session'), findsNothing);
      expect(find.text('80 kg × 5'), findsNothing);
    });
  });

  /// Pushes the editor onto a pumped app shell. The returned future completes
  /// with whatever the editor pops, so callers must not await it before
  /// saving or cancelling.
  Future<WorkoutSession?> pushEditor(
    WidgetTester tester,
    WorkoutSession session,
  ) {
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    return navigator.push<WorkoutSession>(
      MaterialPageRoute<WorkoutSession>(
        builder: (_) => SessionEditPage(session: session),
      ),
    );
  }

  Finder titleField() => find
      .descendant(
        of: find.byType(FTextField),
        matching: find.byType(EditableText),
      )
      .first;

  group('SessionEditPage title', () {
    testWidgets('an empty title cannot be saved', (tester) async {
      await pumpApp(tester);
      pushEditor(tester, pastSession());
      await tester.pumpAndSettle();

      await tester.enterText(titleField(), '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Cannot be empty'), findsOneWidget);
      expect(find.text('Edit session'), findsOneWidget);
    });

    testWidgets('a whitespace-only title counts as empty', (tester) async {
      await pumpApp(tester);
      pushEditor(tester, pastSession());
      await tester.pumpAndSettle();

      await tester.enterText(titleField(), '   ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Cannot be empty'), findsOneWidget);
      expect(find.text('Edit session'), findsOneWidget);
    });

    testWidgets(
      'typing clears the error and saving returns the trimmed title',
      (tester) async {
        await pumpApp(tester);
        final saved = pushEditor(tester, pastSession());
        await tester.pumpAndSettle();

        await tester.enterText(titleField(), '');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(find.text('Cannot be empty'), findsOneWidget);

        await tester.enterText(titleField(), '  Pull  ');
        await tester.pumpAndSettle();
        expect(find.text('Cannot be empty'), findsNothing);

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect((await saved)?.title, 'Pull');
      },
    );
  });

  group('SessionEditPage set weight rules', () {
    Future<void> openSetEditor(WidgetTester tester) async {
      await pumpAppPage(tester, SessionEditPage(session: pastSession()));
      await tester.tap(find.text('80 kg × 5'));
      await tester.pumpAndSettle();
    }

    Finder dialogField(int index) => find
        .descendant(
          of: find.byType(FDialog),
          matching: find.byType(EditableText),
        )
        .at(index);

    Future<void> tapInDialog(WidgetTester tester, String label) async {
      await tester.tap(
        find.descendant(of: find.byType(FDialog), matching: find.text(label)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a negative weight asks for the assisted machine first', (
      tester,
    ) async {
      await openSetEditor(tester);
      await tester.enterText(dialogField(0), '-20');
      await tapInDialog(tester, 'Save');

      expect(find.text('Assisted machine?'), findsOneWidget);
      await tapInDialog(tester, 'Yes, log it');

      expect(find.text('Edit set'), findsNothing);
      expect(find.text('-20 kg × 5'), findsOneWidget);
      expect(find.text('80 kg × 5'), findsNothing);
    });

    testWidgets(
      'a heavy weight asks, and the set keeps its value once confirmed',
      (tester) async {
        await openSetEditor(tester);
        await tester.enterText(dialogField(0), '600');
        await tapInDialog(tester, 'Save');

        expect(find.text("That's a lot of weight"), findsOneWidget);
        await tapInDialog(tester, 'Use this weight');

        expect(find.text('600 kg × 5'), findsOneWidget);
      },
    );

    testWidgets('an out-of-range weight is rejected inside the editor', (
      tester,
    ) async {
      await openSetEditor(tester);
      await tester.enterText(dialogField(0), '10001');
      await tapInDialog(tester, 'Save');

      expect(find.text('Must be between -1000 and 10000'), findsOneWidget);
      expect(find.text('Edit set'), findsOneWidget);
      expect(find.text("That's a lot of weight"), findsNothing);
    });

    testWidgets('weight and reps keep two decimal places', (tester) async {
      await openSetEditor(tester);
      await tester.enterText(dialogField(0), '82.255');
      await tester.enterText(dialogField(1), '3.555');
      await tapInDialog(tester, 'Save');

      expect(find.text('82.25 kg × 3.55'), findsOneWidget);
    });

    testWidgets('reps below one are rejected inside the editor', (
      tester,
    ) async {
      await openSetEditor(tester);
      await tester.enterText(dialogField(1), '.5');
      await tapInDialog(tester, 'Save');

      expect(find.text('Must be at least 1'), findsOneWidget);
      expect(find.text('Edit set'), findsOneWidget);
    });
  });
}
