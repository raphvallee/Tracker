import 'dart:io';

import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/data/services/sample_data.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_split.dart';

/// Test mode: the app runs on a throwaway copy of everything, filled with
/// [seedSampleData], while the real database and saved state stay closed
/// off and untouched. Isar has no in-memory mode, so the sample database
/// is a file in the temporary directory, deleted when it is left, reset or
/// the app starts again.
abstract final class TestMode {
  static File _flag(String documentsPath) =>
      File('$documentsPath${Platform.pathSeparator}tracker_test_mode');

  /// Whether the app was in test mode when it last ran.
  static bool isOn(String documentsPath) => _flag(documentsPath).existsSync();

  static Future<void> remember(String documentsPath, {required bool on}) async {
    final flag = _flag(documentsPath);
    if (on) {
      await flag.create(recursive: true);
    } else if (flag.existsSync()) {
      await flag.delete();
    }
  }

  static int _opened = 0;

  /// A fresh sample database. Each one gets its own name and folder, so a
  /// reset can open the next before the last is closed.
  static Future<(TrackerRepository, SampleData)> openSandbox({
    DateTime? now,
  }) async {
    final root = Directory(
      '${(await getTemporaryDirectory()).path}'
      '${Platform.pathSeparator}tracker_test_mode',
    );
    // Leftovers of an earlier run, which was closed without cleaning up.
    if (_opened == 0 && root.existsSync()) {
      await root.delete(recursive: true);
    }
    final name = 'test_mode_${_opened++}';
    final dir = Directory('${root.path}${Platform.pathSeparator}$name')
      ..createSync(recursive: true);
    final isar = await Isar.open(
      [ExerciseSchema, WorkoutSplitSchema, GymSchema, WorkoutSessionSchema],
      directory: dir.path,
      name: name,
      inspector: false,
    );
    final repo = TrackerRepository(isar);
    final sample = await seedSampleData(repo, now: now);
    return (repo, sample);
  }

  /// Closes a sample database and deletes it.
  static Future<void> closeSandbox(TrackerRepository repo) =>
      repo.close(deleteFromDisk: true);
}

/// Saved state (settings, the running workout, split drafts) kept in
/// memory only: test mode's, gone when it is left.
class MemoryStorage implements Storage {
  MemoryStorage([Map<String, dynamic>? initial]) : _data = {...?initial};

  final Map<String, dynamic> _data;

  @override
  dynamic read(String key) => _data[key];

  @override
  Future<void> write(String key, dynamic value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<void> clear() async => _data.clear();

  @override
  Future<void> close() async {}
}
