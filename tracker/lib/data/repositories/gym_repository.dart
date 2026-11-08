import 'package:isar_community/isar.dart';

import 'package:tracker/domain/models/gym.dart';

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

  Stream<List<Gym>> watchAll() =>
      _isar.gyms.where().watch(fireImmediately: true);
}
