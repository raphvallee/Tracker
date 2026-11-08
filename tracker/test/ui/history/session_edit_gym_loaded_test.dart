// The session editor shows and keeps the stored gym.
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

  testWidgets('the stored gym name shows once loaded and is kept on save', (
    tester,
  ) async {
    final seeded = await pumpPersistenceApp(tester, 'session_edit_gym_loaded');
    await tester.tap(find.text('Edit'));
    await settleSessionFlow(tester);
    await waitForText(tester, 'Home');
    expect(find.text('Home'), findsOneWidget);

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
  });
}
