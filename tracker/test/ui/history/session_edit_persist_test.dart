// A saved session edit re-renders the detail page and persists.
// One Isar-backed case per file: each *_test.dart runs in its own
// flutter_tester process with a fresh libisar native worker pool (see
// docs/TESTING_ISAR_CI.md).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/session_edit_helpers.dart';
import '../../../testing/test_helpers.dart';

void main() {
  setUpAll(initIsarCore);

  setUp(() {
    HydratedBloc.storage = InMemoryStorage();
  });

  testWidgets('saved edit re-renders the detail page and persists the weight', (
    tester,
  ) async {
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
      find.descendant(of: find.byType(FDialog), matching: find.text('Save')),
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
  });
}
