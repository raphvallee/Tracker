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
}
