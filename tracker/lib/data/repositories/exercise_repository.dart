import 'package:isar_community/isar.dart';

import 'package:tracker/domain/models/exercise.dart';

class ExerciseRepository {
  ExerciseRepository(this._isar);

  final Isar _isar;

  Future<List<Exercise>> getAll() => _isar.exercises.where().findAll();

  Future<Exercise?> getById(int id) => _isar.exercises.get(id);

  Future<Exercise?> getByTitle(String title, {int? excludeId}) async {
    final matches = await _isar.exercises
        .filter()
        .titleEqualTo(title, caseSensitive: false)
        .findAll();
    for (final exercise in matches) {
      if (exercise.id != excludeId) return exercise;
    }
    return null;
  }

  Future<int> put(Exercise exercise) =>
      _isar.writeTxn(() => _isar.exercises.put(exercise));

  Future<void> putAll(List<Exercise> exercises) =>
      _isar.writeTxn(() => _isar.exercises.putAll(exercises));

  Future<bool> delete(int id) =>
      _isar.writeTxn(() => _isar.exercises.delete(id));

  Future<int> count() => _isar.exercises.count();

  Future<void> putAllIfEmpty(List<Exercise> exercises) =>
      _isar.writeTxn(() async {
        if (await _isar.exercises.count() != 0) return;
        await _isar.exercises.putAll(exercises);
      });

  Stream<List<Exercise>> watchAll() =>
      _isar.exercises.where().watch(fireImmediately: true);
}
