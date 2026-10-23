import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/muscle.dart';
import 'package:tracker/ui/exercises/widgets/exercises_page.dart';
import 'package:tracker/ui/exercises/widgets/new_exercise_page.dart';

import '../../../testing/test_helpers.dart';

void main() {
  test('muscle-group browsing lists exercise once per group', () {
    final exercise = Exercise(
      title: 'Abdominal crunch',
      primaryMuscle: [Muscle.abdominals, Muscle.obliques],
      equipment: [Equipment.bodyweight],
    );

    final grouped = groupExercisesByMuscle([exercise]);

    expect(grouped.keys, {MuscleGroup.abdominals});
    expect(grouped[MuscleGroup.abdominals], [exercise]);
  });

  test('exercise remains in each distinct muscle group once', () {
    final exercise = Exercise(
      title: 'Squat',
      primaryMuscle: [Muscle.quadriceps, Muscle.glutes, Muscle.hamstrings],
      equipment: [Equipment.barbell],
    );

    final grouped = groupExercisesByMuscle([exercise]);

    expect(grouped.keys, {MuscleGroup.legs});
    expect(grouped[MuscleGroup.legs], [exercise]);
  });

  testWidgets('exercise form flags name and target muscle inline', (
    tester,
  ) async {
    await pumpAppPage(tester, const NewExercisePage());

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Cannot be empty'), findsOneWidget);
    expect(find.text('Pick at least one target muscle'), findsOneWidget);

    // Picking a target muscle clears the inline error without another save.
    final chest = find.text('pectoralis major').first;
    await tester.ensureVisible(chest);
    await tester.pumpAndSettle();
    await tester.tap(chest);
    await tester.pumpAndSettle();
    expect(find.text('Pick at least one target muscle'), findsNothing);
  });
}
