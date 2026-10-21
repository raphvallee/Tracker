// Runs alone in its own process: each Isar-backed case gets a fresh libisar
// native pool (see session_edit_delete_test.dart for why).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
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

  group('SessionDetailPage persistence flows', () {
    testWidgets(
      'saved edit re-renders the detail page and persists the weight',
      (tester) async {
        final seeded = await pumpPersistenceApp(tester, 'session_edit_persist');

        await tester.tap(find.text('Edit'));
        await settleSessionFlow(tester);

        await tester.tap(find.text('80 kg × 5'));
        await settleSessionFlow(tester);
        final fields = find.descendant(
          of: find.byType(FDialog),
          matching: find.byType(EditableText),
        );
        await tester.enterText(fields.first, '90');
        await tester.tap(
          find.descendant(
            of: find.byType(FDialog),
            matching: find.text('Save'),
          ),
        );
        await settleSessionFlow(tester);
        await tester.tap(find.text('Save')); // editor header action
        await settleSessionFlow(tester);

        // The detail page applied the edit immediately.
        expect(find.text('90 kg × 5'), findsOneWidget);
        expect(find.text('80 kg × 5'), findsNothing);

        // The save reached the repository: read the record back from Isar.
        final id = seeded.session.id;
        await waitForRealIo(tester, () async {
          final saved = await seeded.repo.sessions.getById(id);
          return saved?.sets.any((s) => !s.isWarmup && s.weight == 90) ?? false;
        });
        final saved = (await tester.runAsync(
          () => seeded.repo.sessions.getById(id),
        ))!;
        final working = saved.sets.singleWhere((s) => !s.isWarmup);
        expect(working.weight, 90);
        expect(working.reps, 5);
        expect(saved.sets.where((s) => s.isWarmup).single.weight, 60);
      },
    );

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

        // Rename the session so the save has an observable effect to wait on.
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
            of: find.byType(FDialog),
            matching: find.text('Save'),
          ),
        );
        await settleSessionFlow(tester);
        await tester.tap(find.text('Save')); // editor header action
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
  });
}
