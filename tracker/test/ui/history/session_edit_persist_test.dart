// Runs alone in its own process: each Isar-backed case gets a fresh libisar
// native pool (see session_edit_delete_test.dart for why).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/session_edit_helpers.dart';
import '../../../testing/test_helpers.dart';

void main() {
  setUpAll(initIsarCore);

  setUp(() {
    HydratedBloc.storage = InMemoryStorage();
  });

  group('SessionDetailPage persistence flows', () {
    testWidgets('saved edit re-renders the detail page optimistically', (
      tester,
    ) async {
      await pumpPersistenceApp(tester, 'session_edit_persist');

      await tester.tap(find.text('Edit'));
      await settleSessionFlow(tester);

      await tester.tap(find.text('80 kg × 5'));
      await settleSessionFlow(tester);
      final fields = find.descendant(
        of: find.byType(FDialog),
        matching: find.byType(EditableText),
      );
      await tester.enterText(fields.first, '90');
      await tester.tap(
        find.descendant(of: find.byType(FDialog), matching: find.text('Save')),
      );
      await settleSessionFlow(tester);
      await tester.tap(find.text('Save')); // editor header action
      await settleSessionFlow(tester);

      // The detail page applied the edit immediately (persistence is issued
      // in the background; the repository write itself is covered by the
      // repository round-trip test in session_edit_delete_repo_test.dart).
      expect(find.text('90 kg × 5'), findsOneWidget);
      expect(find.text('80 kg × 5'), findsNothing);
    });
  });
}
