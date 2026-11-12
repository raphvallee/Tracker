// Test mode switching. One Isar-backed case per file
// (docs/TESTING_ISAR_CI.md).
import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/data/services/sample_data.dart';
import 'package:tracker/data/services/test_mode.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/routing/app_session.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/core/ui/test_mode_scope.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';

import '../../testing/fakes/in_memory_storage.dart';
import '../../testing/test_helpers.dart';

const _schemas = [
  ExerciseSchema,
  GymSchema,
  WorkoutSplitSchema,
  WorkoutSessionSchema,
];

class _Probe extends StatelessWidget {
  const _Probe();

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox());
}

void main() {
  setUpAll(initIsarCore);

  testWidgets('test mode swaps in the sample data and back, leaving the '
      'real data alone', (tester) async {
    final docs = Directory.systemTemp.createTempSync('test_mode_docs');
    late TrackerRepository real;
    await tester.runAsync(() async {
      real = TrackerRepository(
        await openTestIsar(_schemas, name: 'isar_session_real'),
      );
      await real.gyms.put(Gym(name: 'My gym', isPrimary: true, order: 0));
    });
    final storage = InMemoryStorage();
    await storage.write(
      'SettingsCubit',
      SettingsState(unit: WeightUnit.pounds).toJson(),
    );
    HydratedBloc.storage = storage;
    var opened = 0;
    Future<(TrackerRepository, SampleData)> openSandbox() async {
      final repo = TrackerRepository(
        await openTestIsar(_schemas, name: 'isar_session_sandbox_${opened++}'),
      );
      return (repo, await seedSampleData(repo));
    }

    await tester.pumpWidget(
      AppSession(
        repository: real,
        storage: storage,
        documentsPath: docs.path,
        openSandbox: openSandbox,
        app: MaterialApp(
          builder: (context, child) => FTheme(
            data: FTheme.neutral.light.touch,
            child: TestModeBanner(child: child!),
          ),
          home: const _Probe(),
        ),
      ),
    );
    BuildContext probe() => tester.element(find.byType(_Probe));
    final banner = find.text('Test mode: sample data, reset on every launch');
    expect(RepositoryScope.maybeOf(probe()), same(real));
    expect(banner, findsNothing);

    await tester.runAsync(
      () => TestModeScope.maybeOf(probe())!.setEnabled(true),
    );
    await tester.pump();
    expect(banner, findsOneWidget);
    final sandbox = RepositoryScope.maybeOf(probe())!;
    expect(sandbox, isNot(same(real)));
    final settings = probe().read<SettingsCubit>().state;
    // The real preferences carry over; the graphs are the sample's.
    expect(settings.unit, WeightUnit.pounds);
    expect(settings.graphs, hasLength(5));
    expect(TestMode.isOn(docs.path), isTrue);
    // The real saved settings never see the sample graphs.
    expect((storage.read('SettingsCubit') as Map)['graphs'], isEmpty);
    await tester.runAsync(() async {
      expect(await sandbox.sessions.getAll(), isNotEmpty);
      expect(await real.sessions.getAll(), isEmpty);
    });

    // A reset opens another fresh sample database.
    await tester.runAsync(() => TestModeScope.maybeOf(probe())!.reset());
    await tester.pump();
    expect(RepositoryScope.maybeOf(probe()), isNot(same(sandbox)));
    expect(opened, 2);

    unawaited(TestModeScope.maybeOf(probe())!.setEnabled(false));
    await tester.pump();
    expect(banner, findsNothing);
    expect(RepositoryScope.maybeOf(probe()), same(real));
    expect(HydratedBloc.storage, same(storage));
    expect(probe().read<SettingsCubit>().state.graphs, isEmpty);
    await tester.runAsync(() async {
      expect(await real.gyms.getAll(), hasLength(1));
    });
  });
}
