// Isar-backed: reorder a split's days in the split editor, save, and read the
// split back from Isar. One Isar-backed case per file, so it runs alone in its
// own process (see docs/TESTING_ISAR_CI.md).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/main.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';
import 'package:tracker/ui/workout/widgets/new_split_page.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/session_edit_helpers.dart';
import '../../../testing/test_helpers.dart';

void main() {
  setUpAll(initIsarCore);

  setUp(() {
    HydratedBloc.storage = InMemoryStorage();
  });

  testWidgets('a saved reorder persists the new day order', (tester) async {
    late TrackerRepository repo;
    late WorkoutSplit seeded;
    await tester.runAsync(() async {
      final isar = await openTestIsar([
        ExerciseSchema,
        GymSchema,
        WorkoutSplitSchema,
        WorkoutSessionSchema,
      ], name: 'split_reorder_persist');
      repo = TrackerRepository(isar);
      seeded = WorkoutSplit(
        title: 'Push Pull Legs',
        splitDays: [
          WorkoutSplitDay(title: 'Push', order: 0),
          WorkoutSplitDay(title: 'Pull', order: 1),
          WorkoutSplitDay(title: 'Legs', order: 2),
        ],
      );
      await repo.splits.put(seeded);
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
    await settleSessionFlow(tester);

    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => SplitEditorPage(split: seeded)),
      ),
    );
    await settleSessionFlow(tester);

    final grip = find.byIcon(FLucideIcons.gripHorizontal).at(1);
    final gesture = await tester.startGesture(tester.getCenter(grip));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, -12));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settleSessionFlow(tester);
    await tester.tap(find.text('Save'));
    await settleSessionFlow(tester);

    await waitForRealIo(tester, () async {
      final saved = await repo.splits.getById(seeded.id);
      return saved?.splitDays.map((d) => d.title).join(',') == 'Pull,Push,Legs';
    });

    final saved = await tester.runAsync(() => repo.splits.getById(seeded.id));
    expect(saved, isNotNull);
    expect(saved!.splitDays.map((d) => d.title), ['Pull', 'Push', 'Legs']);
    expect(saved.splitDays.map((d) => d.order), [0, 1, 2]);
  });
}
