import 'package:isar_community/isar.dart';

import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/services/gym_equivalence.dart';

class GymRepository {
  GymRepository(this._isar);

  final Isar _isar;

  Future<List<Gym>> getAll() => _isar.gyms.where().sortByOrder().findAll();

  List<Gym> getAllSync() => _isar.gyms.where().sortByOrder().findAllSync();

  Future<Gym?> getById(int id) => _isar.gyms.get(id);

  Future<Gym?> getPrimary() =>
      _isar.gyms.filter().isPrimaryEqualTo(true).findFirst();

  Future<int> put(Gym gym) => _isar.writeTxn(() => _isar.gyms.put(gym));

  Future<void> putAll(List<Gym> gyms) =>
      _isar.writeTxn(() => _isar.gyms.putAll(gyms));

  Future<bool> delete(int id) => _isar.writeTxn(() => _isar.gyms.delete(id));

  /// Sets [exerciseId]'s factor at gym [gymId] by hand.
  Future<void> setExerciseFactor(int gymId, int exerciseId, double factor) =>
      _update(
        gymId,
        (gym) => gym.perExerciseMultipliers = withManualFactor(
          gym.perExerciseMultipliers,
          exerciseId,
          factor,
        ),
      );

  /// Puts [exerciseId] at gym [gymId] back on its estimate.
  Future<void> clearExerciseFactor(int gymId, int exerciseId) => _update(
    gymId,
    (gym) => gym.perExerciseMultipliers = withoutManualFactor(
      gym.perExerciseMultipliers,
      exerciseId,
    ),
  );

  /// Sets how [exerciseId]'s machine is set up at gym [gymId]; an empty
  /// [note] removes it.
  Future<void> setMachineSetup(int gymId, int exerciseId, String note) =>
      _update(
        gymId,
        (gym) => gym.machineSetups = withSetupNote(
          gym.machineSetups,
          exerciseId,
          note,
        ),
      );

  /// Reads, changes and writes every gym in one transaction; [change] gives
  /// back the gyms it changed.
  Future<void> updateAll(List<Gym> Function(List<Gym> gyms) change) =>
      _isar.writeTxn(() async {
        final gyms = await _isar.gyms.where().sortByOrder().findAll();
        final changed = change(gyms);
        if (changed.isNotEmpty) await _isar.gyms.putAll(changed);
      });

  /// Reads, changes and writes gym [gymId] in one transaction, so a factor
  /// worked out meanwhile is not lost.
  Future<void> _update(int gymId, void Function(Gym gym) change) =>
      _isar.writeTxn(() async {
        final gym = await _isar.gyms.get(gymId);
        if (gym == null) return;
        change(gym);
        await _isar.gyms.put(gym);
      });

  Stream<List<Gym>> watchAll() =>
      _isar.gyms.where().watch(fireImmediately: true);
}
