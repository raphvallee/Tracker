import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
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

  FButton buttonIn(WidgetTester tester, Finder scope, String tooltip) =>
      tester.widget<FButton>(
        find.descendant(
          of: scope,
          matching: find.byWidgetPredicate(
            (w) => w is FButton && w.semanticsTooltip == tooltip,
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

    expect(buttonIn(tester, setRow(0, 0), 'Remove set').onPress, isNull);

    await tester.tap(fButtonByTooltip('Add set'));
    await tester.pumpAndSettle();
    expect(fieldOf(tester, 0, 1).text, '8');
    expect(fieldOf(tester, 0, 1, index: 1).text, '12');

    expect(buttonIn(tester, setRow(0, 1), 'Remove set').onPress, isNotNull);

    await tester.tap(
      find.descendant(
        of: setRow(0, 1),
        matching: fButtonByTooltip('Use fixed reps'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: setRow(0, 1), matching: find.byType(EditableText)),
      findsOneWidget,
    );
    expect(fieldOf(tester, 0, 1).text, '8');

    await tester.tap(fButtonByTooltip('Add set'));
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

    await tester.tap(fButtonByTooltip('Use rep range'));
    await tester.pumpAndSettle();

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

    await tester.tap(fButtonByTooltip('Use rep range'));
    await tester.pumpAndSettle();

    final fields = find.descendant(
      of: setRow(0, 0),
      matching: find.byType(EditableText),
    );
    await tester.enterText(fields.at(0), '12');
    await tester.enterText(fields.at(1), '8');
    await tester.pumpAndSettle();

    expect(find.text('Must be at least the min'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final set = (await result)!.exercises.single.sets.single;
    expect(set.minReps, 12);
    expect(set.maxReps, isNull);
  });

  testWidgets('restores a customized range max after a fixed round trip', (
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

    final fields = find.descendant(
      of: setRow(0, 0),
      matching: find.byType(EditableText),
    );
    await tester.enterText(fields.at(0), '5');
    await tester.enterText(fields.at(1), '9');
    await tester.pumpAndSettle();

    await tester.tap(fButtonByTooltip('Use fixed reps'));
    await tester.pumpAndSettle();
    expect(fieldOf(tester, 0, 0).text, '5');

    await tester.tap(fButtonByTooltip('Use rep range'));
    await tester.pumpAndSettle();
    expect(fieldOf(tester, 0, 0).text, '5');
    expect(fieldOf(tester, 0, 0, index: 1).text, '9');

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final set = (await result)!.exercises.single.sets.single;
    expect(set.minReps, 5);
    expect(set.maxReps, 9);
  });

  testWidgets('falls back to the default max when the min passes it', (
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

    final fields = find.descendant(
      of: setRow(0, 0),
      matching: find.byType(EditableText),
    );
    await tester.enterText(fields.at(0), '5');
    await tester.enterText(fields.at(1), '9');
    await tester.pumpAndSettle();
    await tester.tap(fButtonByTooltip('Use fixed reps'));
    await tester.pumpAndSettle();

    await tester.enterText(fields.at(0), '10');
    await tester.pumpAndSettle();

    await tester.tap(fButtonByTooltip('Use rep range'));
    await tester.pumpAndSettle();
    expect(fieldOf(tester, 0, 0).text, '10');
    expect(fieldOf(tester, 0, 0, index: 1).text, '12');

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final set = (await result)!.exercises.single.sets.single;
    expect(set.minReps, 10);
    expect(set.maxReps, 12);
  });

  testWidgets('a row that shows another set forgets the old remembered max', (
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
            sets: [
              PlannedSet(order: 0, minReps: 8, maxReps: 12),
              PlannedSet(order: 1, minReps: 8, maxReps: 12),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find
          .descendant(of: setRow(0, 0), matching: find.byType(EditableText))
          .at(1),
      '9',
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: setRow(0, 0),
        matching: fButtonByTooltip('Remove set'),
      ),
    );
    await tester.pumpAndSettle();
    expect(fieldOf(tester, 0, 0, index: 1).text, '12');

    await tester.tap(fButtonByTooltip('Use fixed reps'));
    await tester.pumpAndSettle();
    await tester.tap(fButtonByTooltip('Use rep range'));
    await tester.pumpAndSettle();
    expect(fieldOf(tester, 0, 0).text, '8');
    expect(fieldOf(tester, 0, 0, index: 1).text, '12');

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final set = (await result)!.exercises.single.sets.single;
    expect(set.maxReps, 12);
  });

  testWidgets('back with unsaved changes asks before leaving', (tester) async {
    await pumpApp(tester);
    final result = pushEditor(tester, WorkoutSplitDay(title: 'Push'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(FTextField, 'Day name'), 'Pull');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(FLucideIcons.chevronLeft));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final saved = await result;
    expect(saved, isNotNull);
    expect(saved!.title, 'Pull');
  });

  testWidgets('clean day editor leaves without a confirmation', (tester) async {
    await pumpApp(tester);
    final result = pushEditor(tester, WorkoutSplitDay(title: 'Push'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(FLucideIcons.chevronLeft));
    await tester.pumpAndSettle();

    expect(await result, isNull);
    expect(find.text('Discard changes?'), findsNothing);
  });

  testWidgets('set edits mark the day dirty too', (tester) async {
    await pumpApp(tester);
    var result = pushEditor(
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
    await tester.enterText(
      find.descendant(of: setRow(0, 0), matching: find.byType(EditableText)),
      '0',
    );
    await tester.pumpAndSettle();
    expect(find.text('Must be at least 1'), findsOneWidget);

    await tester.tap(find.byIcon(FLucideIcons.chevronLeft));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(await result, isNull);

    result = pushEditor(
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
    await tester.enterText(
      find.descendant(of: setRow(0, 0), matching: find.byType(EditableText)),
      '9',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(FLucideIcons.chevronLeft));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

  testWidgets('planned sets are spaced apart, not flush', (tester) async {
    await pumpApp(tester);
    pushEditor(
      tester,
      WorkoutSplitDay(
        title: 'Push',
        exercises: [
          ExerciseItem(
            exerciseId: 1,
            order: 0,
            sets: [
              for (var i = 0; i < 3; i++) PlannedSet(order: i, minReps: 8),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    Rect gridRowOf(int set) => tester.getRect(
      find.descendant(of: setRow(0, set), matching: find.byType(Row)).first,
    );

    final gap = gridRowOf(1).top - gridRowOf(0).bottom;
    expect(gap, greaterThanOrEqualTo(4));
    expect(gridRowOf(2).top - gridRowOf(1).bottom, closeTo(gap, 0.01));
  });
}
