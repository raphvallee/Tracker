// One Isar-backed case per file: each *_test.dart runs in its own
// flutter_tester process with a fresh libisar native worker pool (see
// docs/TESTING_ISAR_CI.md).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/muscle.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/main.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/core/ui/set_type_chip.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/test_helpers.dart';

void main() {
  setUpAll(initIsarCore);

  setUp(() {
    HydratedBloc.storage = InMemoryStorage();
  });

  testWidgets('free workout adds exercise cards and logs sets per card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    // A free workout picks its exercises from the repository, so
    // pump the real shell scoped to a test Isar with one seeded exercise
    // (pumpApp has no RepositoryScope). Real Isar IO only progresses inside
    // tester.runAsync (same concession as pumpPersistenceApp), and there is
    // no tearDown close: native close never completes in the fake-async
    // zone, the temp DB dies with the test process instead.
    late TrackerRepository repo;
    late int exerciseId;
    await tester.runAsync(() async {
      final isar = await openTestIsar([
        WorkoutSessionSchema,
        ExerciseSchema,
        GymSchema,
      ], name: 'workout_ui_freeform');
      repo = TrackerRepository(isar);
      exerciseId = await repo.exercises.put(
        Exercise(
          title: 'Bench Press',
          primaryMuscle: [Muscle.chest],
          equipment: [Equipment.barbell],
        ),
      );
    });

    // Advances the tree with timed pumps while giving the real event loop
    // room to land widget-zone Isar reads (pumpAndSettle would hang on the
    // feed page's live Isar watcher, forever animating).
    Future<void> pumpUntil(Finder finder) async {
      for (var i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        if (finder.evaluate().isNotEmpty) return;
      }
      fail('expected $finder to become visible');
    }

    final cubit = WorkoutCubit(repository: repo);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      RepositoryProvider<TrackerRepository>.value(
        value: repo,
        child: RepositoryScope(
          repository: repo,
          child: MultiBlocProvider(
            providers: [
              BlocProvider<WorkoutCubit>.value(value: cubit),
              BlocProvider<SettingsCubit>(
                create: (_) => SettingsCubit()..setUnit(WeightUnit.kilograms),
              ),
            ],
            child: const MyApp(),
          ),
        ),
      ),
    );
    await pumpUntil(find.byType(FBottomNavigationBar));

    cubit.startWorkout();
    tester
        .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
        .onChange!(2);
    await pumpUntil(find.text('Add exercise'));

    // A free workout starts with no cards: exercises are added one at a time
    // through the picker, and each gets its own card of set rows.
    expect(find.text('Add an exercise to start logging sets.'), findsOneWidget);
    expect(find.byType(FTextField), findsNothing);
    expect(find.text('Add set'), findsNothing);

    Future<void> pickBenchPress() async {
      await tester.tap(find.text('Add exercise'));
      await pumpUntil(find.text('Bench Press').hitTestable());
      await tester.tap(find.text('Bench Press'));
    }

    await pickBenchPress();
    await pumpUntil(find.text('Add set'));
    await tester.pumpAndSettle();

    expect(cubit.state.plan.single.exerciseId, exerciseId);
    expect(find.text('1. '), findsOneWidget);
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Add an exercise to start logging sets.'), findsNothing);
    expect(find.byType(FTextField), findsNWidgets(2));
    expect(find.byType(SetTypeChip), findsOneWidget);
    expect(
      tester.widget<FTextField>(find.byType(FTextField).at(1)).hint,
      'Reps',
    );

    tester
        .widget<FButton>(
          find.ancestor(
            of: find.text('Add set'),
            matching: find.byType(FButton),
          ),
        )
        .onPress!();
    await tester.pump();
    expect(find.byType(FTextField), findsNWidgets(4));
    final addedWeightText = find
        .descendant(
          of: find.byType(FTextField).at(2),
          matching: find.byType(EditableText),
        )
        .first;
    expect(tester.widget<EditableText>(addedWeightText).controller.text, '');
    expect(cubit.state.sets, isEmpty);

    // The row's W/S chip is its warm-up toggle: flip it before typing, then
    // log the row.
    await tester.tap(find.byType(SetTypeChip).first);
    await tester.pump();
    expect(find.text('W'), findsOneWidget);
    final weightField = find
        .descendant(
          of: find.byType(FTextField).at(0),
          matching: find.byType(EditableText),
        )
        .first;
    final repsField = find
        .descendant(
          of: find.byType(FTextField).at(1),
          matching: find.byType(EditableText),
        )
        .first;
    await tester.enterText(weightField, '50');
    await tester.enterText(repsField, '8');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final state = cubit.state;
    expect(state.sets, hasLength(1));
    expect(state.sets.single.exerciseId, exerciseId);
    expect(state.sets.single.exerciseName, 'Bench Press');
    expect(state.sets.single.type, SetType.warmup);
    expect(find.text('50 kg × 8'), findsNothing);
    expect(tester.widget<EditableText>(weightField).controller.text, '50');
    expect(tester.widget<EditableText>(repsField).controller.text, '8');
    // The next blank row logs a working set again.
    expect(find.text('W'), findsOneWidget);
    expect(find.text('S'), findsOneWidget);

    tester
        .widget<FButton>(
          find.ancestor(
            of: find.text('Add set'),
            matching: find.byType(FButton),
          ),
        )
        .onPress!();
    await tester.pumpAndSettle();
    expect(find.byType(FTextField), findsNWidgets(6));
    final nextWeightText = find
        .descendant(
          of: find.byType(FTextField).at(2),
          matching: find.byType(EditableText),
        )
        .first;
    expect(tester.widget<EditableText>(nextWeightText).controller.text, '');
    expect(cubit.state.sets, hasLength(1));

    final rowWidth =
        tester
            .getSize(
              find.ancestor(
                of: find.byType(FTextField).first,
                matching: find.byType(FCard),
              ),
            )
            .width -
        24;
    final bandEnd = rowWidth * 0.635 * 0.75;
    final fieldRect = tester.getRect(find.byType(FTextField).at(0));

    final bandGesture = await tester.startGesture(
      tester.getCenter(find.byType(FTextField).at(0)),
    );
    await bandGesture.moveBy(Offset(-bandEnd / 2, 0));
    await tester.pump();
    final halfBandTravel =
        fieldRect.left - tester.getRect(find.byType(FTextField).at(0)).left;
    expect(halfBandTravel, lessThan(bandEnd / 2));
    final cancelStartRect = tester.getRect(find.byType(FTextField).at(0));
    await bandGesture.up();
    await tester.pump();
    expect(tester.getRect(find.byType(FTextField).at(0)), cancelStartRect);
    await tester.pump(const Duration(milliseconds: 30));
    final earlySpring = tester.getRect(find.byType(FTextField).at(0)).left;
    expect(earlySpring, greaterThan(cancelStartRect.left));
    expect(earlySpring, lessThan(fieldRect.left));
    await tester.pump(const Duration(milliseconds: 30));
    final laterSpring = tester.getRect(find.byType(FTextField).at(0)).left;
    expect(laterSpring, greaterThan(earlySpring));
    expect(laterSpring, lessThan(fieldRect.left));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(FTextField).at(0)), fieldRect);
    expect(find.text('Delete this set?'), findsNothing);
    expect(cubit.state.sets, hasLength(1));

    final trackGesture = await tester.startGesture(
      tester.getCenter(find.byType(FTextField).at(0)),
    );
    await trackGesture.moveBy(Offset(-bandEnd - 10, 0));
    await tester.pump();
    final atBandEnd = tester.getRect(find.byType(FTextField).at(0)).left;
    expect(fieldRect.left - atBandEnd, lessThan(bandEnd));
    await trackGesture.moveBy(const Offset(-30, 0));
    await tester.pump();
    expect(
      tester.getRect(find.byType(FTextField).at(0)).left,
      closeTo(atBandEnd - 30, 6),
    );
    await trackGesture.cancel();
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(FTextField).at(0)), fieldRect);
    expect(cubit.state.sets, hasLength(1));

    await tester.timedDrag(
      find.byType(FTextField).at(0),
      Offset(-rowWidth * 0.6, 0),
      const Duration(milliseconds: 200),
    );
    await tester.pumpAndSettle();
    expect(find.text('Delete this set?'), findsNothing);
    expect(tester.getRect(find.byType(FTextField).at(0)), fieldRect);
    expect(cubit.state.sets, hasLength(1));

    final rowRect = tester.getRect(find.byType(FTextField).at(0));
    await tester.timedDrag(
      find.byType(FTextField).at(0),
      Offset(-rowWidth * 0.7, 0),
      const Duration(milliseconds: 200),
    );
    await tester.pumpAndSettle();
    expect(cubit.state.sets, hasLength(1));
    expect(find.text('Delete this set?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(cubit.state.sets, hasLength(1));
    expect(tester.getRect(find.byType(FTextField).at(0)), rowRect);
    expect(
      tester
          .widget<EditableText>(
            find
                .descendant(
                  of: find.byType(FTextField).at(0),
                  matching: find.byType(EditableText),
                )
                .first,
          )
          .controller
          .text,
      '50',
    );

    await tester.timedDrag(
      find.byType(FTextField).at(0),
      Offset(-rowWidth * 1.1, 0),
      const Duration(milliseconds: 200),
    );
    await tester.pumpAndSettle();
    expect(find.text('Delete this set?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(cubit.state.sets, isEmpty);
    expect(find.byType(FTextField), findsNWidgets(4));
    expect(
      tester
          .widget<EditableText>(
            find
                .descendant(
                  of: find.byType(FTextField).at(0),
                  matching: find.byType(EditableText),
                )
                .first,
          )
          .controller
          .text,
      '',
    );
    expect(
      tester
          .widget<EditableText>(
            find
                .descendant(
                  of: find.byType(FTextField).at(2),
                  matching: find.byType(EditableText),
                )
                .first,
          )
          .controller
          .text,
      '',
    );

    expect(find.byIcon(FLucideIcons.trash2), findsNWidgets(2));
    await tester.timedDrag(
      find.byType(FTextField).at(0),
      Offset(-rowWidth * 0.7, 0),
      const Duration(milliseconds: 200),
    );
    await tester.pumpAndSettle();
    expect(find.text('Delete this set?'), findsNothing);
    expect(find.byType(FTextField), findsNWidgets(2));

    expect(find.byIcon(FLucideIcons.trash2), findsNothing);
    final loggingRowRect = tester.getRect(find.byType(FTextField).at(0));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(FTextField).at(0)),
    );
    await gesture.moveBy(const Offset(-200, 0));
    await tester.pump();
    final draggedRect = tester.getRect(find.byType(FTextField).at(0));
    expect(draggedRect.left, greaterThan(loggingRowRect.left - 60));
    expect(draggedRect.left, lessThan(loggingRowRect.left - 20));
    expect(find.byIcon(FLucideIcons.trash2), findsNothing);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(FTextField).at(0)), loggingRowRect);
    expect(find.text('Delete this set?'), findsNothing);
    expect(cubit.state.sets, isEmpty);

    await tester.timedDrag(
      find.byType(FTextField).at(0),
      Offset(-rowWidth * 1.1, 0),
      const Duration(milliseconds: 200),
    );
    await tester.pumpAndSettle();
    expect(find.text('Delete this set?'), findsNothing);
    expect(tester.getRect(find.byType(FTextField).at(0)), loggingRowRect);
    expect(cubit.state.sets, isEmpty);
    expect(find.byType(FTextField), findsNWidgets(2));

    // Picking an exercise that already has a card says so instead of adding
    // a second one.
    await pickBenchPress();
    await pumpUntil(find.text('Bench Press is already in this workout'));
    expect(cubit.state.plan, hasLength(1));
    // Let the toast expire so no timer outlives the test.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // A card without sets is removed at once.
    await tester.tap(find.byIcon(FLucideIcons.x));
    await tester.pumpAndSettle();
    expect(cubit.state.plan, isEmpty);
    expect(find.text('Add an exercise to start logging sets.'), findsOneWidget);
  });
}
