// Split day editor tests for the inline sets editing: legacy seeding, the
// mandatory-set rule, adding sets with the configured defaults, and switching
// a set between fixed reps and a rep range - all on the day editor page
// itself (no sub-page, no dialog).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/domain/models/rep_mode.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/workout/widgets/split_day_editor_page.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/test_helpers.dart';

void main() {
  setUp(() {
    // In-memory storage: the real HydratedStorage deadlocks the widget-test
    // fake-async zone once the app shell is pumped - same setup as app_test.
    HydratedBloc.storage = InMemoryStorage();
  });

  /// Pushes [page] onto the root navigator and returns the popped-value
  /// future, so tests can assert on what the editor hands back.
  Future<WorkoutSplitDay?> pushEditor(
    WidgetTester tester,
    WorkoutSplitDay day,
  ) {
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    final result = navigator.push<WorkoutSplitDay>(
      MaterialPageRoute<WorkoutSplitDay>(
        builder: (_) => SplitDayEditorPage(day: day),
      ),
    );
    return result;
  }

  Finder setRow(int exercise, int set) =>
      find.byKey(ValueKey('day-$exercise-set-$set'));

  TextEditingController fieldOf(
    WidgetTester tester,
    int exercise,
    int set, {
    int index = 0,
  }) => tester
      .widget<EditableText>(
        find
            .descendant(
              of: setRow(exercise, set),
              matching: find.byType(EditableText),
            )
            .at(index),
      )
      .controller;

  IconButton buttonIn(WidgetTester tester, Finder scope, String tooltip) =>
      tester.widget<IconButton>(
        find.descendant(
          of: scope,
          matching: find.byWidgetPredicate(
            (w) => w is IconButton && w.tooltip == tooltip,
          ),
        ),
      );

  testWidgets('seeds legacy exercises from their old targets', (tester) async {
    await pumpApp(tester);
    final day = WorkoutSplitDay(
      title: 'Push',
      exercises: [
        ExerciseItem(exerciseId: 1, order: 0, targetSets: 3, targetReps: 10),
      ],
    );
    final result = pushEditor(tester, day);
    await tester.pumpAndSettle();

    // The seeded sets render inline as editable rows.
    expect(find.text('Set 1'), findsOneWidget);
    expect(find.text('Set 2'), findsOneWidget);
    expect(find.text('Set 3'), findsOneWidget);
    expect(fieldOf(tester, 0, 0).text, '10');
    expect(fieldOf(tester, 0, 2).text, '10');

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final saved = await result;
    expect(saved, isNotNull);
    final sets = saved!.exercises.single.sets;
    expect(sets, hasLength(3));
    expect(
      sets.every((s) => s.minReps == 10 && !s.isRange),
      isTrue,
      reason: 'legacy targetSets/targetReps become fixed sets',
    );
  });

  testWidgets('new sets match the previous set mode and values', (
    tester,
  ) async {
    await pumpApp(tester);
    final result = pushEditor(
      tester,
      WorkoutSplitDay(
        title: 'Push',
        exercises: [
          ExerciseItem(
            exerciseId: 1,
            order: 0,
            sets: [PlannedSet(order: 0, minReps: 8, maxReps: 12)],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // Mandatory sets: the only remaining set cannot be removed.
    expect(buttonIn(tester, setRow(0, 0), 'Remove set').onPressed, isNull);

    // Set 2 infers the rep range from set 1.
    await tester.tap(find.byTooltip('Add set'));
    await tester.pumpAndSettle();
    expect(fieldOf(tester, 0, 1).text, '8');
    expect(fieldOf(tester, 0, 1, index: 1).text, '12');

    // With two sets, removal is enabled again.
    expect(buttonIn(tester, setRow(0, 1), 'Remove set').onPressed, isNotNull);

    // Switch set 2 to fixed reps (keeps the min).
    await tester.tap(
      find.descendant(
        of: setRow(0, 1),
        matching: find.byTooltip('Use fixed reps'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: setRow(0, 1), matching: find.byType(EditableText)),
      findsOneWidget,
    );
    expect(fieldOf(tester, 0, 1).text, '8');

    // Set 3 infers fixed reps from set 2.
    await tester.tap(find.byTooltip('Add set'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: setRow(0, 2), matching: find.byType(EditableText)),
      findsOneWidget,
    );
    expect(fieldOf(tester, 0, 2).text, '8');

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final sets = (await result)!.exercises.single.sets;
    expect(sets, hasLength(3));
    expect(sets[0].isRange, isTrue);
    expect(sets[0].minReps, 8);
    expect(sets[0].maxReps, 12);
    expect(sets[1].isRange, isFalse);
    expect(sets[1].minReps, 8);
    expect(sets[2].isRange, isFalse);
    expect(sets[2].minReps, 8);
  });

  testWidgets('seeds items without targets from the default rep mode', (
    tester,
  ) async {
    await pumpApp(tester);
    final result = pushEditor(
      tester,
      WorkoutSplitDay(
        title: 'Push',
        exercises: [ExerciseItem(exerciseId: 1, order: 0)],
      ),
    );
    await tester.pumpAndSettle();

    // Bundled default mode is rep range: two fields, 8 and 12.
    expect(fieldOf(tester, 0, 0).text, '8');
    expect(fieldOf(tester, 0, 0, index: 1).text, '12');

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final set = (await result)!.exercises.single.sets.single;
    expect(set.isRange, isTrue);
    expect(set.minReps, 8);
    expect(set.maxReps, 12);
  });

  testWidgets('honors a fixed default rep mode from settings', (tester) async {
    await pumpApp(tester);
    final settings = SettingsCubit()..setDefaultRepMode(RepMode.fixed);
    addTearDown(settings.close);
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    final result = navigator.push<WorkoutSplitDay>(
      MaterialPageRoute<WorkoutSplitDay>(
        builder: (_) => BlocProvider.value(
          value: settings,
          child: SplitDayEditorPage(
            day: WorkoutSplitDay(
              title: 'Push',
              exercises: [ExerciseItem(exerciseId: 1, order: 0)],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Fixed mode: a single reps field with the configured default reps.
    expect(
      find.descendant(of: setRow(0, 0), matching: find.byType(EditableText)),
      findsOneWidget,
    );
    expect(fieldOf(tester, 0, 0).text, '10');

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final set = (await result)!.exercises.single.sets.single;
    expect(set.isRange, isFalse);
    expect(set.minReps, 10);
  });

  testWidgets('switches a set to a rep range inline', (tester) async {
    await pumpApp(tester);
    final result = pushEditor(
      tester,
      WorkoutSplitDay(
        title: 'Push',
        exercises: [
          ExerciseItem(
            exerciseId: 1,
            order: 0,
            sets: [PlannedSet(order: 0, minReps: 10)],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Use rep range'));
    await tester.pumpAndSettle();

    // Range mode: two fields, max pre-filled from the Settings default.
    expect(fieldOf(tester, 0, 0).text, '10');
    expect(fieldOf(tester, 0, 0, index: 1).text, '12');

    await tester.enterText(
      find
          .descendant(of: setRow(0, 0), matching: find.byType(EditableText))
          .at(0),
      '8',
    );

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final set = (await result)!.exercises.single.sets.single;
    expect(set.minReps, 8);
    expect(set.maxReps, 12);
  });

  testWidgets('rejects a crossed range and normalizes it on save', (
    tester,
  ) async {
    await pumpApp(tester);
    final result = pushEditor(
      tester,
      WorkoutSplitDay(
        title: 'Push',
        exercises: [
          ExerciseItem(
            exerciseId: 1,
            order: 0,
            sets: [PlannedSet(order: 0, minReps: 10)],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Use rep range'));
    await tester.pumpAndSettle();

    final fields = find.descendant(
      of: setRow(0, 0),
      matching: find.byType(EditableText),
    );
    await tester.enterText(fields.at(0), '12');
    await tester.enterText(fields.at(1), '8');
    await tester.pumpAndSettle();

    // Invalid input is flagged inline and never committed.
    expect(find.text('Must be at least the min'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // The last valid value (12-12) is kept and collapses to a fixed set.
    final set = (await result)!.exercises.single.sets.single;
    expect(set.minReps, 12);
    expect(set.maxReps, isNull);
  });
}
