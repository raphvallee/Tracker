// Runs alone in its own process: the gym lookup is real Isar IO, so each
// Isar-backed case gets its own file (see session_edit_delete_test.dart and
// docs/TESTING_ISAR_CI.md for why).

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

  Finder titleField() => find
      .descendant(
        of: find.byType(FTextField),
        matching: find.byType(EditableText),
      )
      .first;

  /// The gym lookups resolve in real time, so poll until [text] renders.
  Future<void> waitForText(WidgetTester tester, String text) =>
      waitForRealIo(tester, () async => find.text(text).evaluate().isNotEmpty);

  group('SessionEditPage gym', () {
    testWidgets('saving before the gym loads keeps the session gym', (
      tester,
    ) async {
      final seeded = await pumpPersistenceApp(tester, 'session_edit_gym_early');
      await tester.tap(find.text('Edit'));
      await settleSessionFlow(tester);
      // The gym lookup is real Isar IO and cannot have resolved yet.
      expect(find.text('Loading...'), findsOneWidget);

      await tester.enterText(titleField(), 'Pull');
      await tester.tap(find.text('Save')); // editor header action
      await settleSessionFlow(tester);

      final id = seeded.session.id;
      await waitForRealIo(tester, () async {
        final saved = await seeded.repo.sessions.getById(id);
        return saved?.title == 'Pull';
      });
      final saved = (await tester.runAsync(
        () => seeded.repo.sessions.getById(id),
      ))!;
      expect(saved.gymId, seeded.session.gymId);
      expect(saved.gymId, isNotNull);
    });

    testWidgets('the stored gym name shows once loaded and is kept on save', (
      tester,
    ) async {
      final seeded = await pumpPersistenceApp(
        tester,
        'session_edit_gym_loaded',
      );
      await tester.tap(find.text('Edit'));
      await settleSessionFlow(tester);
      await waitForText(tester, 'Home');
      expect(find.text('Home'), findsOneWidget);

      await tester.enterText(titleField(), 'Pull');
      await tester.tap(find.text('Save')); // editor header action
      await settleSessionFlow(tester);

      final id = seeded.session.id;
      await waitForRealIo(tester, () async {
        final saved = await seeded.repo.sessions.getById(id);
        return saved?.title == 'Pull';
      });
      final saved = (await tester.runAsync(
        () => seeded.repo.sessions.getById(id),
      ))!;
      expect(saved.gymId, seeded.session.gymId);
    });

    testWidgets('picking No gym clears the gym on save', (tester) async {
      final seeded = await pumpPersistenceApp(tester, 'session_edit_gym_clear');
      await tester.tap(find.text('Edit'));
      await settleSessionFlow(tester);
      await waitForText(tester, 'Home');

      // Opening the picker loads the gym list (real IO) before the sheet shows.
      await tester.tap(find.text('Home'));
      await settleSessionFlow(tester);
      await waitForText(tester, 'Which gym?');
      await settleSessionFlow(tester); // let the sheet finish sliding in
      expect(find.text('Which gym?'), findsOneWidget);
      await tester.tap(find.text('No gym'));
      await settleSessionFlow(tester);
      expect(find.text('No gym'), findsOneWidget);

      await tester.enterText(titleField(), 'Pull');
      await tester.tap(find.text('Save')); // editor header action
      await settleSessionFlow(tester);

      final id = seeded.session.id;
      await waitForRealIo(tester, () async {
        final saved = await seeded.repo.sessions.getById(id);
        return saved?.title == 'Pull';
      });
      final saved = (await tester.runAsync(
        () => seeded.repo.sessions.getById(id),
      ))!;
      expect(saved.gymId, isNull);
    });
  });
}
