import 'package:isar_community/isar.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path_provider/path_provider.dart';

import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_session_legacy.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/models/workout_split.dart';

/// Owns the single [Isar] instance for the app.
///
/// All collections must be registered here; the generated `*Schema` classes
/// come from `dart run build_runner build`.
class DbInstance {
  static Future<Isar> getIsar() async {
    final dir = await getApplicationDocumentsDirectory();
    await migrateRepsToIntToDouble(dir.path);
    return Isar.open([
      ExerciseSchema,
      WorkoutSplitSchema,
      GymSchema,
      WorkoutSessionSchema,
    ], directory: dir.path);
  }

  /// Reps storage widening (int → double), one-time and idempotent.
  ///
  /// Isar's automatic migration zeroes property values when a property type
  /// changes (long → double), so the sessions are read through the legacy
  /// pre-widening schema first ([WorkoutSessionLegacy], whose generated
  /// schema matches the stored one bit for bit) and rewritten with
  /// whole-number doubles after the widened schema opens. On a fresh install
  /// there is no legacy data and this returns immediately; on an
  /// already-migrated database the legacy read is simply empty.
  @visibleForTesting
  static Future<void> migrateRepsToIntToDouble(String directory) async {
    const schemas = [WorkoutSessionSchema, ExerciseSchema, GymSchema];
    final legacy = await Isar.open(
      [WorkoutSessionLegacySchema, ...schemas.sublist(1)],
      directory: directory,
      name: 'migrateReps',
    );
    final oldSessions = await legacy
        .collection<WorkoutSessionLegacy>()
        .where()
        .findAll();
    await legacy.close();
    if (oldSessions.isEmpty) return;

    final migrated = [
      for (final session in oldSessions)
        WorkoutSession(
          title: session.title,
          startTime: session.startTime,
          endTime: session.endTime,
          gymId: session.gymId,
          sets: [
            for (final set in session.sets)
              WorkoutSet(
                exerciseId: set.exerciseId,
                weight: set.weight,
                reps: set.reps.toDouble(),
                type: set.type,
                order: set.order,
              ),
          ],
        ),
    ];

    final target = await Isar.open(schemas, directory: directory);
    try {
      // putAll preserves each object's existing id, so history entries keep
      // their identity across the widening.
      await target.collection<WorkoutSession>().putAll(migrated);
    } finally {
      await target.close();
    }
  }
}
