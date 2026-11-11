// One Isar-backed case per file: each *_test.dart runs in its own
// flutter_tester process with a fresh libisar native worker pool (see
// docs/TESTING_ISAR_CI.md).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/main.dart';
import 'package:tracker/routing/tab_navigation.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/history/widgets/history_page.dart';
import 'package:tracker/ui/history/widgets/session_detail_page.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/session_edit_helpers.dart';
import '../../../testing/test_helpers.dart';

void main() {
  setUpAll(initIsarCore);

  setUp(() {
    HydratedBloc.storage = InMemoryStorage();
  });

  testWidgets(
    'the workout just saved can be restored from its page, and runs again',
    (tester) async {
      late TrackerRepository repo;
      late WorkoutCubit cubit;
      await tester.runAsync(() async {
        final isar = await openTestIsar([
          ExerciseSchema,
          GymSchema,
          WorkoutSessionSchema,
        ], name: 'session_restore');
        repo = TrackerRepository(isar);
        cubit = WorkoutCubit(repository: repo);
        cubit.startPlanWorkout(
          title: 'Push',
          exercises: const [PlanExercise(exerciseId: 1, name: 'Bench Press')],
        );
        cubit.logSet(
          exerciseId: 1,
          exerciseName: 'Bench Press',
          weight: 80,
          reps: 5,
        );
        await cubit.endWorkout();
      });
      addTearDown(cubit.close);
      final id = cubit.state.savedSessionId!;
      final session = (await tester.runAsync(() => repo.sessions.getById(id)))!;

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
      await settleSessionFlow(tester);
      HomePageSingleton().changeTab(TabName.history);
      await settleSessionFlow(tester);
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      // The page on the History tab's own navigator, as the list opens it.
      final historyNavigator = Navigator.of(
        tester.element(find.byType(HistoryPage)),
      );
      expect(identical(historyNavigator, navigator), isFalse);
      historyNavigator.push(
        MaterialPageRoute<void>(
          builder: (_) => SessionDetailPage(session: session),
        ),
      );
      await settleSessionFlow(tester);

      await tester.tap(fButtonByTooltip('Workout options'));
      await settleSessionFlow(tester);
      await tester.tap(find.text('Restore workout'));
      await waitForRealIo(
        tester,
        () async => (await repo.sessions.getById(id)) == null,
      );
      await settleSessionFlow(tester);

      expect(cubit.state.isInProgress, isTrue);
      expect(cubit.state.sets.single.weight, 80);
      // Off History, onto the running workout.
      expect(find.byType(SessionDetailPage, skipOffstage: false), findsNothing);
      expect(find.byType(HistoryPage), findsNothing);
    },
  );
}
