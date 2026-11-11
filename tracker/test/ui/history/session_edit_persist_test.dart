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

  testWidgets(
    'Save writes the draft, keeps what it does not edit and shows it',
    (tester) async {
      final seeded = await pumpPersistenceApp(
        tester,
        'session_edit_persist',
        splitId: 5,
        splitDayIndex: 1,
        rpe: 8,
      );

      await tester.tap(find.text('Edit'));
      await settleSessionFlow(tester);

      // Nothing is written while editing: the draft only lives on the page.
      await tester.tap(find.textContaining('80 kg × 5'));
      await settleSessionFlow(tester);
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.bySemanticsLabel('Increase weight'));
        await tester.pump();
      }
      await settleSessionFlow(tester);
      expect(find.text('1 unsaved change'), findsOneWidget);
      final id = seeded.session.id;
      final untouched = await waitForSession(tester, seeded.repo, id);
      expect(untouched.sets.first.weight, 80);

      await tapSaveBar(tester);
      final saved = await waitForSession(
        tester,
        seeded.repo,
        id,
        (saved) => saved.sets.any((s) => !s.isWarmup && s.weight == 90),
      );
      await settleSessionFlow(tester);

      // Back on the past workout, which shows the saved values.
      expect(find.text('Edit workout'), findsNothing);
      expect(find.text('90'), findsOneWidget);
      expect(find.text('RPE 8'), findsOneWidget);

      final working = saved.sets.singleWhere((s) => !s.isWarmup);
      expect(working.weight, 90);
      expect(working.reps, 5);
      expect(working.rpe, 8);
      expect(saved.sets.where((s) => s.isWarmup).single.weight, 60);
      expect(saved.splitId, 5);
      expect(saved.splitDayIndex, 1);
      expect(saved.gymId, seeded.session.gymId);
    },
  );
}
