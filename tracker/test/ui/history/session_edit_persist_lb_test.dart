// One Isar-backed case per file: each *_test.dart runs in its own
// flutter_tester process with a fresh libisar native worker pool (see
// docs/TESTING_ISAR_CI.md).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/ui/core/ui/edit_sheet.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/session_edit_helpers.dart';
import '../../../testing/test_helpers.dart';

void main() {
  setUpAll(initIsarCore);

  setUp(() {
    HydratedBloc.storage = InMemoryStorage();
  });

  testWidgets(
    'pounds: saving an untouched set keeps its stored weight exactly',
    (tester) async {
      final seeded = await pumpPersistenceApp(
        tester,
        'session_edit_persist_lb',
        unit: WeightUnit.pounds,
      );

      await tester.tap(find.text('Edit'));
      await settleSessionFlow(tester);

      final title = find
          .descendant(
            of: find.byType(FTextField),
            matching: find.byType(EditableText),
          )
          .first;
      await tester.enterText(title, 'Push (renamed)');

      // In lb the row shows 80 kg as a rounded pounds value. Opening the set
      // and saving it without typing must not convert that rounded text back.
      await tester.tap(find.textContaining(' × 5'));
      await settleSessionFlow(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(EditSheet),
          matching: find.text('Save'),
        ),
      );
      await settleSessionFlow(tester);
      await tester.tap(find.text('Save'));
      await settleSessionFlow(tester);

      final id = seeded.session.id;
      await waitForRealIo(tester, () async {
        final saved = await seeded.repo.sessions.getById(id);
        return saved?.title == 'Push (renamed)';
      });
      final saved = (await tester.runAsync(
        () => seeded.repo.sessions.getById(id),
      ))!;
      final working = saved.sets.singleWhere((s) => !s.isWarmup);
      expect(working.weight, 80);
      expect(working.reps, 5);
    },
  );
}
