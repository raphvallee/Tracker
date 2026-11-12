// One Isar-backed case per file: each *_test.dart runs in its own
// flutter_tester process with a fresh libisar native worker pool (see
// docs/TESTING_ISAR_CI.md).

import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/ui/history/widgets/session_edit_page.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/session_edit_helpers.dart';
import '../../../testing/test_helpers.dart';

void main() {
  setUpAll(initIsarCore);

  setUp(() {
    HydratedBloc.storage = InMemoryStorage();
  });

  testWidgets('the stored gym shows on the first frame and is kept on save', (
    tester,
  ) async {
    final seeded = await pumpPersistenceApp(tester, 'session_edit_gym_early');
    await tester.tap(find.text('Edit'));
    // The button presses on the next frame; the page builds on the one after,
    // before any real IO could land.
    await tester.pump();
    await tester.pump();
    final page = find.byType(SessionEditPage);
    expect(page, findsOneWidget);
    expect(
      find.descendant(of: page, matching: find.text('Home')),
      findsOneWidget,
    );
    await settleSessionFlow(tester);
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
    expect(saved.gymId, isNotNull);
  });
}
