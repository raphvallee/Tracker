import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:isar_community/isar.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/muscle.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/main.dart';
import 'package:tracker/routing/tab_navigation.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';
import 'package:tracker/ui/workout/widgets/new_split_page.dart';

import '../testing/fakes/in_memory_storage.dart';
import '../testing/test_helpers.dart';

void _mark(String what) => debugPrint('DEMO: $what');

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initIsarCore);

  late TrackerRepository repo;
  late Isar isar;

  setUpAll(() async {
    isar = await openTestIsar([
      ExerciseSchema,
      GymSchema,
      WorkoutSplitSchema,
      WorkoutSessionSchema,
    ], name: 'isar_split_discard_demo');
    repo = TrackerRepository(isar);

    final exercise = Exercise(
      title: 'Bench Press',
      primaryMuscle: [Muscle.chest],
      equipment: [Equipment.barbell],
    );
    await repo.exercises.put(exercise);
    await repo.gyms.put(Gym(name: 'Iron Temple'));
    final split = WorkoutSplit(
      title: 'Push Pull Legs',
      description: '3-day rotation',
    );
    split.splitDays = [
      WorkoutSplitDay(
        title: 'Push',
        description: 'Chest, shoulders, triceps',
        exercises: [
          ExerciseItem(
            exerciseId: exercise.id,
            order: 0,
            sets: [PlannedSet(order: 0, minReps: 8, maxReps: 12)],
          ),
        ],
      ),
      WorkoutSplitDay(title: 'Pull', order: 1),
      WorkoutSplitDay(title: 'Legs', order: 2),
    ];
    await repo.splits.put(split);
  });

  testWidgets('split editor discard guard walkthrough', (tester) async {
    HydratedBloc.storage = InMemoryStorage();
    await tester.pumpWidget(
      RepositoryProvider<TrackerRepository>.value(
        value: repo,
        child: RepositoryScope(
          repository: repo,
          child: MultiBlocProvider(
            providers: [
              BlocProvider<WorkoutCubit>(
                create: (_) => WorkoutCubit(repository: repo),
                lazy: false,
              ),
              BlocProvider<SettingsCubit>(
                create: (_) => SettingsCubit(),
                lazy: false,
              ),
            ],
            child: const MyApp(),
          ),
        ),
      ),
    );
    await _settle(tester);

    Future<void> pause([int ms = 900]) async {
      await Future<void>.delayed(Duration(milliseconds: ms));
      await tester.pump();
    }

    _mark('open Editor tab');
    HomePageSingleton().changeTab(TabName.editor);
    await _settle(tester);
    await pause(1200);

    _mark('open split editor');
    await tester.tap(find.text('Push Pull Legs'));
    await _settle(tester);
    await pause(1200);

    _mark('back on a clean editor - pops immediately');
    await tester.tap(find.byIcon(FLucideIcons.chevronLeft));
    await _settle(tester);
    await pause(1200);

    _mark('reopen split and rename it');
    await tester.tap(find.text('Push Pull Legs'));
    await _settle(tester);
    await pause(600);
    await tester.enterText(
      find.widgetWithText(FTextField, 'Split name'),
      'Push Pull Legs RENAMED',
    );
    await _settle(tester);
    await pause(800);

    _mark('back with unsaved changes - dialog appears');
    await tester.tap(find.byIcon(FLucideIcons.chevronLeft));
    await _settle(tester);
    await pause(1400);

    _mark('cancel - stay in the editor');
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    await pause(1400);

    _mark('back again - discard this time');
    await tester.tap(find.byIcon(FLucideIcons.chevronLeft));
    await _settle(tester);
    await pause(1000);
    await tester.tap(find.text('Discard'));
    await _settle(tester);
    await pause(1400);

    _mark('rename was not saved');
    await tester.tap(find.text('Push Pull Legs'));
    await _settle(tester);
    await pause(1200);
    final editable = tester.widget<EditableText>(
      find
          .descendant(
            of: find.widgetWithText(FTextField, 'Split name'),
            matching: find.byType(EditableText),
          )
          .first,
    );
    _mark('title in editor: "${editable.controller.text}"');
    expect(editable.controller.text, 'Push Pull Legs');

    await tester.tap(find.byIcon(FLucideIcons.chevronLeft));
    await _settle(tester);
    await pause(1000);

    _mark('open day editor (clean)');
    await tester.tap(find.text('Push Pull Legs'));
    await _settle(tester);
    await pause(1000);
    final pushRow = find.descendant(
      of: find.byType(SplitEditorPage),
      matching: find.text('Push'),
    );
    await tester.tap(pushRow.first);
    await _settle(tester);
    await pause(1200);

    _mark('back on a clean day editor - pops immediately');
    await tester.tap(find.byIcon(FLucideIcons.chevronLeft));
    await _settle(tester);
    await pause(1200);

    _mark('reopen day editor, add a set (dirty)');
    await tester.tap(pushRow.first);
    await _settle(tester);
    await pause(800);
    await tester.tap(fButtonByTooltip('Add set'));
    await _settle(tester);
    await pause(800);

    _mark('back in day editor - dialog appears');
    await tester.tap(find.byIcon(FLucideIcons.chevronLeft));
    await _settle(tester);
    await pause(1400);
    await tester.tap(find.text('Discard'));
    await _settle(tester);
    await pause(1200);

    await tester.tap(find.byIcon(FLucideIcons.chevronLeft));
    await _settle(tester);

    _mark('done');
    await pause(1500);
    await tester.pump(const Duration(seconds: 3));
  });
}

/// Bounded settle for the real window: short real delays plus a pump, no
/// pumpAndSettle (loading spinners animate forever).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await tester.pump();
  }
}
