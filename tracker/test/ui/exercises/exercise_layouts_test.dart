import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/exercises_layout.dart';
import 'package:tracker/domain/models/muscle.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/domain/services/exercise_library.dart';
import 'package:tracker/ui/exercises/widgets/exercises_page.dart';
import 'package:tracker/ui/exercises/widgets/library_parts.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/settings/widgets/settings_page.dart';

import '../../../testing/test_helpers.dart';

// No repository in these tests: the page shows the library it is given.

Exercise _exercise(
  int id,
  String title,
  List<Muscle> muscles, {
  List<Equipment> equipment = const [Equipment.barbell],
}) =>
    Exercise(title: title, primaryMuscle: muscles, equipment: equipment)
      ..id = id;

// The current split plans Bench Press, Barbell Row and Face Pull on Upper,
// Deadlift on Lower: three of Back's seven exercises.
final _upperLower = WorkoutSplit(
  title: 'Upper Lower',
  splitDays: [
    WorkoutSplitDay(
      title: 'Upper',
      exercises: [
        for (final id in [1, 2, 6]) ExerciseItem(exerciseId: id),
      ],
    ),
    WorkoutSplitDay(title: 'Lower', exercises: [ExerciseItem(exerciseId: 4)]),
  ],
)..id = 1;

ExerciseLibrary _library({bool split = true}) {
  final now = DateTime.now();
  return ExerciseLibrary.read(
    exercises: [
      _exercise(1, 'Bench Press', [Muscle.chest]),
      _exercise(2, 'Barbell Row', [Muscle.lats, Muscle.traps]),
      _exercise(3, 'Pull Up', [Muscle.lats], equipment: [Equipment.bodyweight]),
      _exercise(4, 'Deadlift', [Muscle.lowerBack, Muscle.hamstrings]),
      _exercise(5, 'Lat Pulldown', [Muscle.lats], equipment: [Equipment.cable]),
      _exercise(6, 'Face Pull', [Muscle.rearDelts, Muscle.traps]),
      _exercise(7, 'Shrug', [Muscle.traps]),
      _exercise(8, 'Back Extension', [Muscle.lowerBack]),
    ],
    sessions: [
      WorkoutSession(
        startTime: now.subtract(const Duration(days: 1)),
        sets: [
          WorkoutSet(exerciseId: 1, weight: 100, reps: 5),
          WorkoutSet(exerciseId: 1, weight: 100, reps: 6),
        ],
      ),
      WorkoutSession(
        startTime: now.subtract(const Duration(days: 3)),
        sets: [
          WorkoutSet(exerciseId: 2, weight: 80, reps: 8),
          WorkoutSet(exerciseId: 3, reps: 10),
        ],
      ),
    ],
    splits: split ? [_upperLower] : const [],
    now: now,
  );
}

Future<void> _pump(
  WidgetTester tester,
  ExercisesLayout layout, {
  bool split = true,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await pumpAppPage(
    tester,
    ExercisesPage(initialLibrary: _library(split: split)),
  );
  tester
      .element(find.byType(ExercisesPage).last)
      .read<SettingsCubit>()
      .setExercisesLayout(layout);
  await tester.pumpAndSettle();
}

Finder _inPage(Finder finder) =>
    find.descendant(of: find.byType(ExercisesPage).last, matching: finder);

void main() {
  testWidgets('tiles that open list a group below its row', (tester) async {
    await _pump(tester, ExercisesLayout.openTiles);

    // Recently trained, latest first, with last time's top set.
    expect(find.byKey(const ValueKey('recent-1')), findsOneWidget);
    expect(_inPage(find.text('100 kg × 6')), findsOneWidget);
    expect(_inPage(find.text('All 8')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('exercise-group-muscle-back')));
    await tester.pumpAndSettle();
    // Back has seven exercises: five, then the rest behind Show more.
    expect(_inPage(find.text('Show 2 more')), findsOneWidget);
    expect(_inPage(find.text('Back Extension')), findsOneWidget);
    expect(_inPage(find.text('Shrug')), findsNothing);
    expect(_inPage(find.text('Not trained yet')), findsWidgets);

    // Row, Deadlift and Face Pull are in the split.
    expect(_inPage(find.text('3 of 7 in your split')), findsOneWidget);
    expect(_inPage(find.text('In split')), findsNWidgets(3));

    await tester.tap(_inPage(find.text('Show 2 more')));
    await tester.pumpAndSettle();
    expect(_inPage(find.text('Shrug')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('exercise-group-muscle-back')));
    await tester.pumpAndSettle();
    expect(_inPage(find.text('Back Extension')), findsNothing);

    // The split's days, named after it; a day's exercises go untagged.
    await tester.tap(_inPage(find.text('By split day')));
    await tester.pumpAndSettle();
    expect(_inPage(find.text('Upper Lower')), findsOneWidget);
    expect(_inPage(find.text('Chest, back and shoulders')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('exercise-group-day-0')));
    await tester.pumpAndSettle();
    expect(_inPage(find.text('Face Pull')), findsOneWidget);
    expect(_inPage(find.text('In split')), findsNothing);
  });

  testWidgets('tiles by muscle break groups down and list recent ones', (
    tester,
  ) async {
    await _pump(tester, ExercisesLayout.tiles);

    expect(_inPage(find.text('Lats')), findsOneWidget);
    expect(_inPage(find.text('Lower back')), findsOneWidget);
    expect(_inPage(find.text('New exercise')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('library-view-split')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('exercise-group-day-1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('library-view-equipment')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('exercise-group-equipment-cable')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('library-view-recent')));
    await tester.pumpAndSettle();
    expect(_inPage(find.text('Bench Press')), findsOneWidget);
    expect(_inPage(find.text('10 reps')), findsOneWidget);
    expect(_inPage(find.text('Deadlift')), findsNothing);
  });

  testWidgets('a list of groups opens a group on its own page', (tester) async {
    await _pump(tester, ExercisesLayout.rows);

    expect(_inPage(find.text('Upper Lower')), findsOneWidget);
    expect(_inPage(find.text('By equipment')), findsOneWidget);
    expect(
      _inPage(find.text('7 exercises, 3 of 7 in your split')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('exercise-group-muscle-back')));
    await tester.pumpAndSettle();
    expect(find.text('Shrug'), findsOneWidget);
    expect(find.text('80 kg × 8'), findsOneWidget);
    expect(find.text('7 exercises, 3 of 7 in your split'), findsWidgets);
    Navigator.of(tester.element(find.text('Shrug'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('exercise-group-day-0')));
    await tester.pumpAndSettle();
    expect(find.text('3 exercises in Upper Lower'), findsOneWidget);
  });

  testWidgets('without a split, nothing counts toward one', (tester) async {
    await _pump(tester, ExercisesLayout.rows, split: false);
    expect(_inPage(find.byType(CoverageRing)), findsNothing);
    expect(_inPage(find.text('7 exercises')), findsOneWidget);

    tester
        .element(find.byType(ExercisesPage).last)
        .read<SettingsCubit>()
        .setExercisesLayout(ExercisesLayout.openTiles);
    await tester.pumpAndSettle();
    expect(_inPage(find.text('By split day')), findsNothing);
    expect(_inPage(find.byType(CoverageBar)), findsNothing);

    tester
        .element(find.byType(ExercisesPage).last)
        .read<SettingsCubit>()
        .setExercisesLayout(ExercisesLayout.tiles);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('library-view-split')), findsNothing);
    expect(_inPage(find.byType(SquareCount)), findsNothing);
  });

  testWidgets('search lists matches and offers a way out of none', (
    tester,
  ) async {
    await _pump(tester, ExercisesLayout.openTiles);

    await tester.enterText(
      find.byKey(const ValueKey('exercise-search')),
      'lats',
    );
    await tester.pumpAndSettle();
    expect(_inPage(find.text('3 exercises')), findsOneWidget);
    expect(_inPage(find.text('Lat Pulldown')), findsOneWidget);
    expect(_inPage(find.text('Bench Press')), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('exercise-search')),
      'zzz',
    );
    await tester.pumpAndSettle();
    expect(_inPage(find.text('No exercises match')), findsOneWidget);

    await tester.tap(_inPage(find.text('Clear search')));
    await tester.pumpAndSettle();
    expect(_inPage(find.text('Recently trained')), findsOneWidget);
  });

  testWidgets('Settings picks the layout of the Exercises tab', (tester) async {
    await pumpAppPage(tester, const SettingsPage());
    final cubit = tester
        .element(find.byType(SettingsPage))
        .read<SettingsCubit>();
    expect(find.text('List of groups'), findsOneWidget);

    await tester.tap(find.text('Exercises').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Layout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiles by muscle'));
    await tester.pumpAndSettle();

    expect(cubit.state.exercisesLayout, ExercisesLayout.tiles);
  });
}
