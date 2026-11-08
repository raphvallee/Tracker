// Free-form logging on the CurrentWorkout tab: exercise dropdown, warm-up
// toggle, Add set rows and swipe-to-delete.
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
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/test_helpers.dart';

void main() {
  setUpAll(initIsarCore);

  setUp(() {
    HydratedBloc.storage = InMemoryStorage();
  });

  testWidgets('free-form logging keeps the warm-up toggle and add button', (
    tester,
  ) async {
    // Tall enough that the footer row clears the bottom navigation bar.
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    // A free workout loads its exercise dropdown from the repository, so
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
    await pumpUntil(find.text('Log a set'));

    // Free-form logging keeps its own affordances: the exercise dropdown,
    // the warm-up toggle and the Add set button (no planned hints). (The
    // exercise dropdown must match FSelect via a predicate: FSelect's
    // constructor redirects to a private subclass, so byType never matches.
    // It renders an internal read-only field too, so the form shows three
    // FTextFields: exercise, weight, reps.)
    final exerciseDropdown = find.byWidgetPredicate((w) => w is FSelect<int>);
    expect(find.text('Add set'), findsOneWidget);
    expect(find.byType(FCheckbox), findsOneWidget);
    expect(exerciseDropdown, findsOneWidget);
    expect(find.byType(FTextField), findsNWidgets(3));
    final repsField = find
        .descendant(
          of: find.byType(FTextField).at(2),
          matching: find.byType(EditableText),
        )
        .first;
    expect(
      tester.widget<FTextField>(find.byType(FTextField).at(2)).hint,
      'Reps',
    );
    expect(tester.widget<EditableText>(repsField).controller.text, '');

    // Tapping Add set must materialize the blank row immediately, before
    // any cubit emission: the row lives in the form now, not behind the
    // next state-driven rebuild.
    tester
        .widget<FButton>(
          find.ancestor(
            of: find.text('Add set'),
            matching: find.byType(FButton),
          ),
        )
        .onPress!();
    await tester.pump();
    expect(find.byType(FTextField), findsNWidgets(5)); // 2 rows + dropdown
    final addedWeightText = find
        .descendant(
          of: find.byType(FTextField).at(3),
          matching: find.byType(EditableText),
        )
        .first;
    expect(tester.widget<EditableText>(addedWeightText).controller.text, '');
    expect(cubit.state.sets, isEmpty);

    // Pick the exercise through the dropdown's open picker (hit-testing the
    // popover's animated overlay is unreliable under the test zone, so
    // invoke the tile's press handler directly), then log a warm-up set via
    // the kept controls.
    await tester.tap(exerciseDropdown.first);
    await pumpUntil(find.text('Bench Press').hitTestable());
    tilePress() => tester
        .widget<FItem>(
          find
              .ancestor(
                of: find.text('Bench Press'),
                matching: find.byType(FItem),
              )
              .first,
        )
        .onPress!;
    tilePress()();
    // The tile's press hides the popover (auto-hide) before lifting the
    // selection; pump the hide animation to completion so the selection
    // lands and no animation timer outlives the test.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find
          .ancestor(of: find.text('Bench Press'), matching: find.byType(FItem))
          .evaluate()
          .isEmpty) {
        break;
      }
    }
    await tester.pump();

    final weightField = find
        .descendant(
          of: find.byType(FTextField).at(1),
          matching: find.byType(EditableText),
        )
        .first;
    await tester.enterText(weightField, '50');
    await tester.enterText(repsField, '8');
    // Tapping the warm-up toggle does not move focus away from the row
    // (only focus change commits), so the flag applies to the set when it
    // finally commits - here through the keyboard's done action.
    await tester.ensureVisible(find.byType(FCheckbox));
    await tester.tap(find.byType(FCheckbox));
    // Forui tappables (checkbox included) defer their press callbacks
    // through 100ms press/up timers; pump past them so the toggle lands and
    // no timer outlives the test.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final state = cubit.state;
    expect(state.sets, hasLength(1));
    expect(state.sets.single.exerciseId, exerciseId);
    expect(state.sets.single.exerciseName, 'Bench Press');
    expect(state.sets.single.type, SetType.warmup);
    // No rendered-set display: the logged set keeps living in its inputs,
    // and the warm-up flag reset is ready for the next set.
    expect(find.text('50 kg × 8'), findsNothing);
    expect(tester.widget<EditableText>(weightField).controller.text, '50');
    expect(tester.widget<EditableText>(repsField).controller.text, '8');
    expect(tester.widget<FCheckbox>(find.byType(FCheckbox)).value, isFalse);

    // Add set appends another empty row below the committed one (on top of
    // the blank row added above, which the commit consumed).
    tester
        .widget<FButton>(
          find.ancestor(
            of: find.text('Add set'),
            matching: find.byType(FButton),
          ),
        )
        .onPress!();
    await tester.pumpAndSettle();
    expect(find.byType(FTextField), findsNWidgets(7)); // 3 rows + dropdown
    final nextWeightText = find
        .descendant(
          of: find.byType(FTextField).at(3),
          matching: find.byType(EditableText),
        )
        .first;
    expect(tester.widget<EditableText>(nextWeightText).controller.text, '');
    expect(cubit.state.sets, hasLength(1));

    // A deletable row is rubber-banded for the first 75% of the delete
    // distance - the row lags the finger there - and tracks the finger 1:1
    // from there to the delete distance, 63.5% of the row's width.
    // The row fills the card's inner width (the card pads 12 on each side).
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
    final fieldRect = tester.getRect(find.byType(FTextField).at(1));

    final bandGesture = await tester.startGesture(
      tester.getCenter(find.byType(FTextField).at(1)),
    );
    await bandGesture.moveBy(Offset(-bandEnd / 2, 0));
    await tester.pump();
    final halfBandTravel =
        fieldRect.left - tester.getRect(find.byType(FTextField).at(1)).left;
    // Rubber-banded: the row moved less than the finger did.
    expect(halfBandTravel, lessThan(bandEnd / 2));
    // Releasing inside the band cancels: the row springs back to rest over
    // several frames - it must not teleport - and no dialog opens.
    final cancelStartRect = tester.getRect(find.byType(FTextField).at(1));
    await bandGesture.up();
    await tester.pump();
    expect(tester.getRect(find.byType(FTextField).at(1)), cancelStartRect);
    await tester.pump(const Duration(milliseconds: 30));
    final earlySpring = tester.getRect(find.byType(FTextField).at(1)).left;
    expect(earlySpring, greaterThan(cancelStartRect.left));
    expect(earlySpring, lessThan(fieldRect.left));
    await tester.pump(const Duration(milliseconds: 30));
    final laterSpring = tester.getRect(find.byType(FTextField).at(1)).left;
    expect(laterSpring, greaterThan(earlySpring));
    expect(laterSpring, lessThan(fieldRect.left));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(FTextField).at(1)), fieldRect);
    expect(find.text('Delete this set?'), findsNothing);
    expect(cubit.state.sets, hasLength(1));

    final trackGesture = await tester.startGesture(
      tester.getCenter(find.byType(FTextField).at(1)),
    );
    await trackGesture.moveBy(Offset(-bandEnd - 10, 0));
    await tester.pump();
    final atBandEnd = tester.getRect(find.byType(FTextField).at(1)).left;
    // Still lagging the finger when the band ends...
    expect(fieldRect.left - atBandEnd, lessThan(bandEnd));
    await trackGesture.moveBy(const Offset(-30, 0));
    await tester.pump();
    // ...then nearly keeping pace with it (the mid-swipe stretch only
    // bleeds a few pixels off those 30px of travel).
    expect(
      tester.getRect(find.byType(FTextField).at(1)).left,
      closeTo(atBandEnd - 30, 6),
    );
    await trackGesture.cancel();
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(FTextField).at(1)), fieldRect);
    expect(cubit.state.sets, hasLength(1));

    // Past the band but short of the gate the swipe still springs back:
    // 60% of the row width is not enough to delete.
    await tester.timedDrag(
      find.byType(FTextField).at(1),
      Offset(-rowWidth * 0.6, 0),
      const Duration(milliseconds: 200),
    );
    await tester.pumpAndSettle();
    expect(find.text('Delete this set?'), findsNothing);
    expect(tester.getRect(find.byType(FTextField).at(1)), fieldRect);
    expect(cubit.state.sets, hasLength(1));

    // Swipe-to-delete (free workouts only): a swipe of at least 63.5% of the
    // row width on the first row (the logged set) opens the destructive
    // confirmation first.
    final rowRect = tester.getRect(find.byType(FTextField).at(1));
    await tester.timedDrag(
      find.byType(FTextField).at(1),
      Offset(-rowWidth * 0.7, 0),
      const Duration(milliseconds: 200),
    );
    await tester.pumpAndSettle();
    expect(cubit.state.sets, hasLength(1)); // asked, not removed yet
    expect(find.text('Delete this set?'), findsOneWidget);

    // Cancelling keeps the set and returns the row: the row does not stay
    // frozen mid-swipe but sits back exactly where it was.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(cubit.state.sets, hasLength(1));
    expect(tester.getRect(find.byType(FTextField).at(1)), rowRect);
    expect(
      tester
          .widget<EditableText>(
            find
                .descendant(
                  of: find.byType(FTextField).at(1),
                  matching: find.byType(EditableText),
                )
                .first,
          )
          .controller
          .text,
      '50',
    );

    // Confirming removes the set and shifts the remaining rows up: row 0
    // now holds nothing (the deleted set is gone) and stays blank.
    await tester.timedDrag(
      find.byType(FTextField).at(1),
      Offset(-rowWidth * 1.1, 0),
      const Duration(milliseconds: 200),
    );
    await tester.pumpAndSettle();
    expect(find.text('Delete this set?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(cubit.state.sets, isEmpty);
    // The logged set is gone; the trailing blank rows (the always-available
    // one plus the added extra) remain for the next entry.
    expect(find.byType(FTextField), findsNWidgets(5));
    expect(
      tester
          .widget<EditableText>(
            find
                .descendant(
                  of: find.byType(FTextField).at(1),
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
                  of: find.byType(FTextField).at(3),
                  matching: find.byType(EditableText),
                )
                .first,
          )
          .controller
          .text,
      '',
    );

    // A blank extra row (Add set) is still removable silently, but it never
    // asks: there is nothing to lose. It needs the same 63.5% swipe.
    expect(find.byIcon(FLucideIcons.trash2), findsNWidgets(2));
    await tester.timedDrag(
      find.byType(FTextField).at(1),
      Offset(-rowWidth * 0.7, 0),
      const Duration(milliseconds: 200),
    );
    await tester.pumpAndSettle();
    expect(find.text('Delete this set?'), findsNothing);
    expect(find.byType(FTextField), findsNWidgets(3));

    // Only the always-available logging row is left, and it cannot be
    // deleted: no delete indicator is revealed at rest (the trash icon
    // only exists while a deletable row is mid-swipe), a swipe rubber-bands
    // with sqrt resistance (200px of finger travel move it only ~50px), and
    // it springs back on release without ever opening the dialog.
    expect(find.byIcon(FLucideIcons.trash2), findsNothing);
    final loggingRowRect = tester.getRect(find.byType(FTextField).at(1));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(FTextField).at(1)),
    );
    await gesture.moveBy(const Offset(-200, 0));
    await tester.pump();
    final draggedRect = tester.getRect(find.byType(FTextField).at(1));
    expect(draggedRect.left, greaterThan(loggingRowRect.left - 60));
    expect(draggedRect.left, lessThan(loggingRowRect.left - 20));
    expect(find.byIcon(FLucideIcons.trash2), findsNothing);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(FTextField).at(1)), loggingRowRect);
    expect(find.text('Delete this set?'), findsNothing);
    expect(cubit.state.sets, isEmpty);

    // Even a swipe past the delete distance cannot delete it: deletability,
    // not distance, is the gate.
    await tester.timedDrag(
      find.byType(FTextField).at(1),
      Offset(-rowWidth * 1.1, 0),
      const Duration(milliseconds: 200),
    );
    await tester.pumpAndSettle();
    expect(find.text('Delete this set?'), findsNothing);
    expect(tester.getRect(find.byType(FTextField).at(1)), loggingRowRect);
    expect(cubit.state.sets, isEmpty);
    expect(find.byType(FTextField), findsNWidgets(3));
  });
}
