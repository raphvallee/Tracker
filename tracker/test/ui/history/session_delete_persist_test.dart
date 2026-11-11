// Runs alone in its own process: each Isar-backed case gets a fresh libisar
// native pool (see docs/TESTING_ISAR_CI.md).

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

  testWidgets(
    'Delete from the edit menu asks, removes the record and leaves both pages',
    (tester) async {
      final seeded = await pumpPersistenceApp(tester, 'session_delete_persist');

      // Never one tap away: not on the past workout itself.
      expect(find.textContaining('Delete'), findsNothing);
      await tester.tap(find.text('Edit'));
      await settleSessionFlow(tester);
      expect(find.textContaining('Delete'), findsNothing);

      await tester.tap(fButtonByTooltip('Workout options'));
      await settleSessionFlow(tester);
      await tester.tap(find.text('Delete workout'));
      await settleSessionFlow(tester);
      expect(find.text('Delete this workout?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FButton, 'Delete'));
      await settleSessionFlow(tester);

      final id = seeded.session.id;
      await waitForRealIo(
        tester,
        () async => (await seeded.repo.sessions.getById(id)) == null,
      );
      await settleSessionFlow(tester);
      await settleSessionFlow(tester);

      // Both the edit page and the past workout left the stack.
      expect(find.text('Edit workout'), findsNothing);
      expect(find.text('Delete this workout?'), findsNothing);
      expect(find.text('Edit'), findsNothing);
      final remaining = await tester.runAsync(
        () => seeded.repo.sessions.getById(id),
      );
      expect(remaining, isNull);
    },
  );
}
