// One Isar-backed case per file: each *_test.dart runs in its own
// flutter_tester process with a fresh libisar native worker pool (see
// docs/TESTING_ISAR_CI.md).

import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/domain/models/weight_unit.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/session_edit_helpers.dart';
import '../../../testing/test_helpers.dart';

void main() {
  setUpAll(initIsarCore);

  setUp(() {
    HydratedBloc.storage = InMemoryStorage();
  });

  testWidgets(
    'pounds: a set stepped away and back keeps its stored weight exactly',
    (tester) async {
      final seeded = await pumpPersistenceApp(
        tester,
        'session_edit_persist_lb',
        unit: WeightUnit.pounds,
      );

      await tester.tap(find.text('Edit'));
      await settleSessionFlow(tester);

      // In lb the row shows 80 kg as a rounded pounds value. Stepping it up
      // and back down must land on the stored kilograms, not on the rounded
      // text converted back.
      await tester.tap(find.textContaining(' × 5'));
      await settleSessionFlow(tester);
      await tester.tap(find.bySemanticsLabel('Increase weight'));
      await settleSessionFlow(tester);
      expect(find.text('1 unsaved change'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Decrease weight'));
      await settleSessionFlow(tester);
      expect(find.textContaining('unsaved change'), findsNothing);

      await renameWorkout(tester, 'Push (renamed)');
      await tapSaveBar(tester);

      final id = seeded.session.id;
      final saved = await waitForSession(
        tester,
        seeded.repo,
        id,
        (saved) => saved.title == 'Push (renamed)',
      );
      final working = saved.sets.singleWhere((s) => !s.isWarmup);
      expect(working.weight, 80);
      expect(working.reps, 5);
    },
  );
}
