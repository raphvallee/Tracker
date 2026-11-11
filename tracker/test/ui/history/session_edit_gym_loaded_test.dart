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

    await renameWorkout(tester, 'Pull');
    await tapSaveBar(tester);

    final id = seeded.session.id;
    final saved = await waitForSession(
      tester,
      seeded.repo,
      id,
      (saved) => saved.title == 'Pull',
    );
    expect(saved.gymId, seeded.session.gymId);
  });
}
