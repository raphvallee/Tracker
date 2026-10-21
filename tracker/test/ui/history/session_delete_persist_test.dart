// Runs alone in its own process: each Isar-backed case gets a fresh libisar
// native pool (see session_edit_delete_test.dart for why).

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
    testWidgets('delete confirms, then pops back to the list', (tester) async {
      await pumpPersistenceApp(tester, 'session_delete_persist');

      await tester.tap(find.text('Delete session'));
      await settleSessionFlow(tester);
      expect(find.text('Delete session?'), findsOneWidget);
      expect(find.widgetWithText(FButton, 'Delete'), findsOneWidget);
      await tester.tap(find.widgetWithText(FButton, 'Delete'));
      await settleSessionFlow(tester);
      await settleSessionFlow(tester);

      // The detail page popped back to the shell and the record deletion was
      // issued in the background (verified at the repository layer in
      // session_edit_delete_repo_test.dart).
      expect(find.text('Delete session'), findsNothing);
      expect(find.text('Delete session?'), findsNothing);
    });
  });
}
