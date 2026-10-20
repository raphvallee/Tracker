// History edit/delete tests (lib/ui/history/). Two layers:
//  1. Widget-only: the detail page surfaces Edit/Delete, the editor renders
//     prefilled fields, and editing a set through the dialog updates the draft.
//  2. Repository-backed: an edit/delete initiated from the UI round-trips
//     through WorkoutSessionRepository (real temp Isar, like the data tests).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/muscle.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/main.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/history/widgets/session_detail_page.dart';
import 'package:tracker/ui/history/widgets/session_edit_page.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/test_helpers.dart';

void main() {
  setUpAll(initIsarCore);

  setUp(() {
    // The app shell pumps HydratedCubits, which read storage at construction;
    // the real storage deadlocks the widget-test fake-async zone.
    HydratedBloc.storage = InMemoryStorage();
  });

  group('SessionDetailPage actions', () {
    testWidgets('offers Edit and Delete for a past session', (tester) async {
      await pumpAppPage(
        tester,
        SessionDetailPage(session: _session(), gymName: 'Home'),
      );

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete session'), findsOneWidget);
    });
  });

  group('SessionEditPage', () {
    testWidgets('renders prefilled session fields and sets', (tester) async {
      await pumpAppPage(tester, SessionEditPage(session: _session()));

      expect(find.text('Edit session'), findsOneWidget); // app bar title
      expect(find.text('Save'), findsOneWidget); // app bar action
      expect(find.text('No gym'), findsOneWidget); // no repository in scope
      expect(find.text('80 kg × 5'), findsOneWidget);
      expect(find.text('60 kg × 8'), findsOneWidget);
      final title = find
          .descendant(
            of: find.byType(FTextField),
            matching: find.byType(EditableText),
          )
          .first;
      expect(tester.widget<EditableText>(title).controller.text, 'Push');
    });

    testWidgets('editing a set through the dialog updates the draft row', (
      tester,
    ) async {
      await pumpAppPage(tester, SessionEditPage(session: _session()));

      // Tap the 80 kg × 5 row to open the per-set editor.
      await tester.tap(find.text('80 kg × 5'));
      await tester.pumpAndSettle();
      expect(find.text('Edit set'), findsOneWidget);

      // Weight and reps arrive prefilled; overwrite them and make warm-up.
      final fields = find.descendant(
        of: find.byType(FDialog),
        matching: find.byType(EditableText),
      );
      expect(fields, findsNWidgets(2));
      expect(tester.widget<EditableText>(fields.first).controller.text, '80');
      expect(tester.widget<EditableText>(fields.last).controller.text, '5');
      await tester.enterText(fields.first, '82.5');
      await tester.enterText(fields.last, '3');
      await tester.tap(find.text('Warm-up'));
      await tester.tap(
        find.descendant(of: find.byType(FDialog), matching: find.text('Save')),
      );
      await tester.pumpAndSettle();

      // The draft row re-renders with the new values (kg is the default
      // test unit) and the W chip count follows the toggled type.
      expect(find.text('82.5 kg × 3'), findsOneWidget);
      expect(find.text('80 kg × 5'), findsNothing);
      expect(find.text('W'), findsNWidgets(2));
      expect(find.text('S'), findsNothing);
    });

    testWidgets('Save pops back out of the editor', (tester) async {
      await pumpAppPage(tester, SessionEditPage(session: _session()));

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Edit session'), findsNothing);
      expect(find.text('80 kg × 5'), findsNothing);
    });
  });

  group('SessionDetailPage persistence flows', () {
    testWidgets('saved edit re-renders the detail page optimistically', (
      tester,
    ) async {
      await _pumpPersistenceApp(tester, 'session_edit_persist');

      await tester.tap(find.text('Edit'));
      await _settle(tester);

      await tester.tap(find.text('80 kg × 5'));
      await _settle(tester);
      final fields = find.descendant(
        of: find.byType(FDialog),
        matching: find.byType(EditableText),
      );
      await tester.enterText(fields.first, '90');
      await tester.tap(
        find.descendant(of: find.byType(FDialog), matching: find.text('Save')),
      );
      await _settle(tester);
      await tester.tap(find.text('Save')); // editor header action
      await _settle(tester);

      // The detail page applied the edit immediately (persistence is issued
      // in the background; the repository write itself is covered by the
      // repository round-trip test below - real Isar IO never completes
      // inside this fake-async zone).
      expect(find.text('90 kg × 5'), findsOneWidget);
      expect(find.text('80 kg × 5'), findsNothing);
    });

    testWidgets('delete confirms, then pops back to the list', (tester) async {
      await _pumpPersistenceApp(tester, 'session_delete_persist');

      await tester.tap(find.text('Delete session'));
      await _settle(tester);
      expect(find.text('Delete session?'), findsOneWidget);
      expect(find.widgetWithText(FButton, 'Delete'), findsOneWidget);
      await tester.tap(find.widgetWithText(FButton, 'Delete'));
      await _settle(tester);
      await _settle(tester);

      // The detail page popped back to the shell and the record deletion was
      // issued in the background (verified at the repository layer below).
      expect(find.text('Delete session'), findsNothing);
      expect(find.text('Delete session?'), findsNothing);
    });
  });

  test('edited/deleted session round-trips through the repository', () async {
    // The exact repository operations the detail page issues after its
    // dialogs: an editor draft put back under the same id, then a delete.
    // (Plain async test so real Isar IO can complete.)
    final isar = await openTestIsar([
      ExerciseSchema,
      GymSchema,
      WorkoutSessionSchema,
    ], name: 'session_edit_delete_repo');
    final repo = TrackerRepository(isar);
    addTearDown(isar.close);

    final gymId = await repo.gyms.put(Gym(name: 'Home', isPrimary: true));
    final session = _session(exerciseId: 1, gymId: gymId);
    final id = await repo.sessions.put(session);

    final edited = WorkoutSession(
      title: 'Push (edited)',
      startTime: session.startTime.add(const Duration(hours: 1)),
      endTime: session.endTime,
      gymId: null,
      sets: [
        for (final set in session.sets)
          if (!set.isWarmup)
            WorkoutSet(
              exerciseId: set.exerciseId,
              weight: 90,
              reps: set.reps,
              type: set.type,
              order: set.order,
            ),
      ],
    )..id = id;
    await repo.sessions.put(edited);

    final persisted = (await repo.sessions.getById(id))!;
    expect(persisted.title, 'Push (edited)');
    expect(persisted.gymId, isNull);
    expect(persisted.sets, hasLength(1));
    expect(persisted.sets.single.weight, 90);
    expect(persisted.sets.single.isWarmup, isFalse);

    expect(await repo.sessions.delete(id), isTrue);
    expect(await repo.sessions.getById(id), isNull);
  });
}

WorkoutSession _session({int exerciseId = 1, int? gymId}) => WorkoutSession(
  title: 'Push',
  startTime: DateTime(2026, 1, 1, 9),
  endTime: DateTime(2026, 1, 1, 10),
  gymId: gymId,
  sets: [
    WorkoutSet(
      exerciseId: exerciseId,
      weight: 80,
      reps: 5,
      type: SetType.working,
      order: 0,
    ),
    WorkoutSet(
      exerciseId: exerciseId,
      weight: 60,
      reps: 8,
      type: SetType.warmup,
      order: 1,
    ),
  ],
);

/// Seeds a session into a fresh temp Isar (real IO inside [tester.runAsync],
/// same concession as the visual sweep), then pumps the app shell with the
/// matching [RepositoryScope] and pushes the detail page for that session.
///
/// No isar.close(): native close never completes inside the fake-async zone;
/// the temp DB dies with the test process.
Future<void> _pumpPersistenceApp(WidgetTester tester, String dbName) async {
  late TrackerRepository repo;
  late WorkoutSession session;
  await tester.runAsync(() async {
    final isar = await openTestIsar([
      ExerciseSchema,
      GymSchema,
      WorkoutSessionSchema,
    ], name: dbName);
    repo = TrackerRepository(isar);
    final exerciseId = await repo.exercises.put(
      Exercise(
        title: 'Bench Press',
        primaryMuscle: [Muscle.chest],
        equipment: [Equipment.barbell],
        movementPattern: MovementPattern.push,
      ),
    );
    final gymId = await repo.gyms.put(Gym(name: 'Home', isPrimary: true));
    session = _session(exerciseId: exerciseId, gymId: gymId);
    await repo.sessions.put(session);
  });

  final cubit = WorkoutCubit(repository: repo);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    RepositoryScope(
      repository: repo,
      child: MultiBlocProvider(
        providers: [
          BlocProvider<WorkoutCubit>.value(value: cubit),
          BlocProvider<SettingsCubit>(create: (_) => SettingsCubit()),
        ],
        child: const MyApp(),
      ),
    ),
  );
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  unawaited(
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => SessionDetailPage(session: session),
      ),
    ),
  );
  await _settle(tester);
}

/// Advances past route/dialog animations with timed pumps. The shell's feed
/// page sits on a real Isar watcher that never settles inside the fake-async
/// zone (its loading spinner animates forever), so pumpAndSettle would time
/// out here.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump(const Duration(milliseconds: 400));
}
