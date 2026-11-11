// Widget-only: no Isar, so History has no workouts to list. The list itself
// is covered by the Isar-backed history_page_first_frame_test.dart and
// history_calendar_jump_test.dart, one case per file.

import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/routing/tab_navigation.dart';
import 'package:tracker/ui/history/widgets/history_page.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

import '../../../testing/test_helpers.dart';

void main() {
  Future<void> openHistory(WidgetTester tester) async {
    HomePageSingleton().changeTab(TabName.history);
    await tester.pumpAndSettle();
    expect(find.byType(HistoryPage), findsOneWidget);
  }

  Future<void> discardAWorkout(WorkoutCubit cubit) async {
    cubit.startPlanWorkout(
      title: 'Legs',
      exercises: const [PlanExercise(exerciseId: 1, name: 'Squat')],
    );
    for (var i = 0; i < 3; i++) {
      cubit.logSet(
        exerciseId: 1,
        exerciseName: 'Squat',
        weight: 100,
        reps: 5,
        type: i == 0 ? SetType.warmup : SetType.working,
      );
    }
    await cubit.discardWorkout();
  }

  group('HistoryPage', () {
    testWidgets('an empty history says what will show up here', (tester) async {
      await pumpApp(tester);
      await openHistory(tester);

      expect(find.text('No workouts logged yet'), findsOneWidget);
      expect(
        find.textContaining('Finish a workout in the Workout tab'),
        findsOneWidget,
      );
      // Nothing to pick on a calendar.
      expect(fButtonByTooltip('Calendar'), findsNothing);
      expect(find.textContaining('was discarded'), findsNothing);
    });

    testWidgets('a discarded workout can be restored from the top', (
      tester,
    ) async {
      final cubit = await pumpApp(tester);
      await discardAWorkout(cubit);
      await openHistory(tester);

      expect(find.text('Legs was discarded'), findsOneWidget);
      expect(find.text('Today at '), findsNothing);
      expect(find.textContaining('Today at '), findsOneWidget);
      expect(find.textContaining('3 sets logged'), findsOneWidget);

      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();

      expect(cubit.state.isInProgress, isTrue);
      expect(cubit.state.planTitle, 'Legs');
      expect(cubit.state.sets, hasLength(3));
      // It is running again: the Workout tab shows it.
      expect(find.byType(HistoryPage), findsNothing);
      expect(find.byType(HistoryPage, skipOffstage: false), findsOneWidget);
      expect(
        find.textContaining('was discarded', skipOffstage: false),
        findsNothing,
      );
    });

    testWidgets('no restore offer while another workout runs', (tester) async {
      final cubit = await pumpApp(tester);
      await discardAWorkout(cubit);
      cubit.startWorkout();
      await openHistory(tester);

      expect(find.textContaining('was discarded'), findsNothing);
      expect(cubit.state.discardedSnapshot, isNotNull);
    });
  });
}
