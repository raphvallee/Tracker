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

  testWidgets('the gym shows at once, never "Loading...", and is kept', (
    tester,
  ) async {
    final seeded = await pumpPersistenceApp(tester, 'session_edit_gym_early');
    await tester.tap(find.text('Edit'));
    // The page's first frame, before any real IO could land.
    await tester.pump();
    expect(find.text('Loading...'), findsNothing);
    await settleSessionFlow(tester);
    expect(find.text('Home'), findsOneWidget);

    await renameWorkout(tester, 'Pull');
    await tapSaveBar(tester);

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
