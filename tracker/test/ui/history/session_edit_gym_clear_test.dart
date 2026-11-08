// Picking Other gym in the session editor clears the gym.
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

  testWidgets('picking Other gym clears the gym on save', (tester) async {
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
    await tester.tap(find.text('Other gym'));
    await settleSessionFlow(tester);
    expect(find.text('Other gym'), findsOneWidget);

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
    expect(saved.gymId, isNull);
  });
}
