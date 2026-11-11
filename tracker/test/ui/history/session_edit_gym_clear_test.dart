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

    await tester.tap(find.text('Home'));
    await settleSessionFlow(tester);
    await waitForText(tester, 'Which gym?');
    await settleSessionFlow(tester);
    expect(find.text('Which gym?'), findsOneWidget);
    await tester.tap(find.text('Other gym'));
    await settleSessionFlow(tester);
    expect(find.text('Other gym'), findsOneWidget);
    expect(find.text('1 unsaved change'), findsOneWidget);

    await renameWorkout(tester, 'Pull');
    await tapSaveBar(tester);

    final id = seeded.session.id;
    final saved = await waitForSession(
      tester,
      seeded.repo,
      id,
      (saved) => saved.title == 'Pull',
    );
    expect(saved.gymId, isNull);
  });
}
