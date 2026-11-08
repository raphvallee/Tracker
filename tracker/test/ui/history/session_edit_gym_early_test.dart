// Saving the session editor before its gym lookup resolves.
// One Isar-backed case per file: each *_test.dart runs in its own
// flutter_tester process with a fresh libisar native worker pool (see
// docs/TESTING_ISAR_CI.md).

import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/session_edit_helpers.dart';
import '../../../testing/test_helpers.dart';

void main() {
  setUpAll(initIsarCore);

  setUp(() {
    HydratedBloc.storage = InMemoryStorage();
  });

  testWidgets('saving before the gym loads keeps the session gym', (
    tester,
  ) async {
    final seeded = await pumpPersistenceApp(tester, 'session_edit_gym_early');
    await tester.tap(find.text('Edit'));
    await settleSessionFlow(tester);
    // The gym lookup is real Isar IO and cannot have resolved yet.
    expect(find.text('Loading...'), findsOneWidget);

    await tester.enterText(sessionTitleField(), 'Pull');
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
}
