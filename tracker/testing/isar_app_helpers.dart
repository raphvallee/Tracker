import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/number_entry.dart';
import 'package:tracker/main.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/splits/view_models/split_drafts_cubit.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

/// The cubits a repository-backed app test drives.
typedef RealApp = ({
  WorkoutCubit workout,
  SettingsCubit settings,
  SplitDraftsCubit drafts,
});

/// Pumps the real shell scoped to [repo]. The caller sets up HydratedBloc
/// storage, and opens [repo] inside `tester.runAsync`.
Future<RealApp> pumpRealApp(WidgetTester tester, TrackerRepository repo) async {
  final workout = WorkoutCubit(repository: repo);
  final settings = SettingsCubit()..setNumberEntry(NumberEntry.phoneKeyboard);
  final drafts = SplitDraftsCubit(repository: repo);
  addTearDown(workout.close);
  addTearDown(settings.close);
  addTearDown(drafts.close);
  await tester.pumpWidget(
    RepositoryProvider<TrackerRepository>.value(
      value: repo,
      child: RepositoryScope(
        repository: repo,
        child: MultiBlocProvider(
          providers: [
            BlocProvider<WorkoutCubit>.value(value: workout),
            BlocProvider<SettingsCubit>.value(value: settings),
            BlocProvider<SplitDraftsCubit>.value(value: drafts),
          ],
          child: const MyApp(),
        ),
      ),
    ),
  );
  return (workout: workout, settings: settings, drafts: drafts);
}

/// Timed pumps that leave the real event loop room to land widget-zone Isar
/// reads, until [finder] finds something (pumpAndSettle would hang on the
/// live Isar watchers).
Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('expected $finder to become visible');
}

/// [pumpUntil]'s pumping, while [condition] holds.
Future<void> pumpWhile(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 60 && condition(); i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  }
  expect(condition(), isFalse, reason: 'timed out waiting');
}

/// A few rounds of [pumpUntil]'s pumping, for changes with nothing new to
/// wait for.
Future<void> pumpRounds(WidgetTester tester, [int rounds = 4]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  }
}
