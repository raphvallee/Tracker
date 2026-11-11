import 'dart:math' as math;

import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/data/services/seed.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/models/workout_split.dart';

/// What [seedSampleData] made, for what is set up around it (test mode's
/// graphs, its current split).
class SampleData {
  const SampleData({
    required this.exerciseIds,
    required this.currentSplitId,
    required this.previousSplitId,
    required this.previousSplitUsedAt,
  });

  /// The library's exercises by title.
  final Map<String, int> exerciseIds;

  /// Push Pull Legs, trained these last months.
  final int currentSplitId;

  /// Upper Lower, trained before it.
  final int previousSplitId;
  final DateTime previousSplitUsedAt;
}

/// One lift of the sample lifter: its 1RM at the start of the history and
/// now, and the step its weights are rounded to.
class _Lift {
  const _Lift(this.from, this.to, {this.step = 2.5});

  final double from;
  final double to;
  final double step;
}

const _lifts = <String, _Lift>{
  'Bench Press': _Lift(80, 104),
  'Incline Bench Press': _Lift(62, 80),
  'Overhead Press': _Lift(47, 60),
  'Triceps Pushdown': _Lift(32, 44),
  'Squat': _Lift(105, 142.5),
  'Romanian Deadlift': _Lift(85, 112.5),
  'Leg Press': _Lift(160, 225, step: 5),
  'Deadlift': _Lift(130, 167.5),
  'Barbell Row': _Lift(70, 90),
  'Lat Pulldown': _Lift(55, 72.5),
  'Pull Up': _Lift(0, 0),
  'Dumbbell Curl': _Lift(14, 20, step: 1),
};

/// A planned exercise: its title, warm-ups, working sets and rep range.
typedef _Planned = (String, int warmups, int sets, int min, int? max);

const _ppl = <(String, List<_Planned>)>[
  (
    'Push',
    [
      ('Bench Press', 2, 4, 6, 8),
      ('Overhead Press', 1, 3, 8, 10),
      ('Incline Bench Press', 0, 3, 10, null),
      ('Triceps Pushdown', 0, 3, 12, 15),
    ],
  ),
  (
    'Pull',
    [
      ('Deadlift', 2, 3, 5, null),
      ('Barbell Row', 1, 4, 8, null),
      ('Lat Pulldown', 0, 3, 10, 12),
      ('Dumbbell Curl', 0, 3, 12, null),
    ],
  ),
  (
    'Legs',
    [
      ('Squat', 2, 4, 5, null),
      ('Romanian Deadlift', 1, 3, 8, null),
      ('Leg Press', 0, 3, 10, 12),
    ],
  ),
];

const _upperLower = <(String, List<_Planned>)>[
  (
    'Upper',
    [
      ('Bench Press', 2, 3, 5, 8),
      ('Barbell Row', 1, 3, 8, null),
      ('Overhead Press', 0, 3, 8, 10),
      ('Pull Up', 0, 3, 6, 10),
    ],
  ),
  (
    'Lower',
    [
      ('Squat', 2, 3, 5, null),
      ('Romanian Deadlift', 1, 3, 8, null),
      ('Leg Press', 0, 3, 10, 12),
    ],
  ),
];

/// Fills an empty database with fourteen months of training up to [now]:
/// the exercise library, two gyms, two splits and the sessions trained from
/// them, with warm-ups, ratings, a break, a few free workouts and steady
/// progress. The same [now] always gives the same data.
Future<SampleData> seedSampleData(
  TrackerRepository repo, {
  DateTime? now,
}) async {
  final today = now ?? DateTime.now();
  await seedExercisesIfNeeded(repo);
  final ids = {
    for (final exercise in await repo.exercises.getAll())
      exercise.title: exercise.id,
  };

  final home = Gym(name: 'Iron Temple', isPrimary: true, order: 0);
  final away = Gym(
    name: 'Hotel gym',
    description: 'Lighter plates: weights read 10% heavy',
    order: 1,
    multiplier: 0.9,
  );
  await repo.gyms.putAll([home, away]);

  WorkoutSplit split(
    String title,
    String about,
    int order,
    List<(String, List<_Planned>)> days,
  ) => WorkoutSplit(
    title: title,
    description: about,
    order: order,
    splitDays: [
      for (final (i, (day, plan)) in days.indexed)
        WorkoutSplitDay(
          title: day,
          order: i,
          exercises: [
            for (final (j, (name, warmups, sets, min, max)) in plan.indexed)
              ExerciseItem(
                exerciseId: ids[name]!,
                order: j,
                sets: [
                  for (var k = 0; k < warmups + sets; k++)
                    PlannedSet(
                      order: k,
                      minReps: k < warmups ? (k == 0 ? 10 : 5) : min,
                      maxReps: k < warmups ? null : max,
                      isWarmup: k < warmups,
                    ),
                ],
              ),
          ],
        ),
    ],
  );
  final ppl = split('Push Pull Legs', 'Five days a week', 0, _ppl);
  final upperLower = split('Upper Lower', 'Four days a week', 1, _upperLower);
  await repo.splits.put(ppl);
  await repo.splits.put(upperLower);

  final random = math.Random(42);
  const span = 425;
  const switchedAt = 140;
  const breakFrom = 232, breakTo = 218;
  final sessions = <WorkoutSession>[];

  double lift(String name, int daysAgo) {
    final l = _lifts[name]!;
    final t = 1 - daysAgo / span;
    var value = l.from + (l.to - l.from) * math.pow(t, 0.75);
    // A little lighter just back from the break.
    if (daysAgo < breakTo && daysAgo > breakTo - 14) value *= 0.95;
    return value * (0.98 + random.nextDouble() * 0.04);
  }

  double round(double weight, double step) =>
      math.max(0, (weight / step).round() * step).toDouble();

  WorkoutSession train(
    DateTime day,
    int daysAgo,
    String title,
    List<_Planned> plan, {
    int? splitId,
    int? dayIndex,
  }) {
    final atAway = random.nextDouble() < 0.08;
    final start = DateTime(
      day.year,
      day.month,
      day.day,
      17 + random.nextInt(3),
      random.nextInt(4) * 15,
    );
    final sets = <WorkoutSet>[];
    for (final (name, warmups, count, min, max) in plan) {
      final l = _lifts[name]!;
      final oneRm = lift(name, daysAgo);
      final reps = (min + random.nextInt((max ?? min) - min + 1)).toDouble();
      // At the away gym the plates read heavier for the same effort.
      final scale = atAway ? 1 / 0.9 : 1.0;
      final working = round(
        oneRm / (1 + reps / 30) * (0.95 + random.nextDouble() * 0.04) * scale,
        l.step,
      );
      for (var w = 0; w < warmups; w++) {
        sets.add(
          WorkoutSet(
            exerciseId: ids[name]!,
            weight: round(working * (w == 0 ? 0.5 : 0.7), l.step),
            reps: w == 0 ? 10 : 5,
            type: SetType.warmup,
            order: sets.length,
          ),
        );
      }
      for (var s = 0; s < count; s++) {
        final tired = s > 0 && random.nextDouble() < 0.35 ? 1 : 0;
        sets.add(
          WorkoutSet(
            exerciseId: ids[name]!,
            weight: working,
            reps: math.max(1, reps - tired - (s == count - 1 ? tired : 0)),
            order: sets.length,
            rpe: math.min(10, 7 + s * 0.5 + (random.nextBool() ? 0.5 : 0)),
          ),
        );
      }
    }
    return WorkoutSession(
      title: title,
      startTime: start,
      endTime: start.add(Duration(minutes: 50 + random.nextInt(35))),
      gymId: atAway ? away.id : home.id,
      splitId: splitId,
      splitDayIndex: dayIndex,
      sets: sets,
    );
  }

  var rotation = 0;
  var thursdays = 0;
  DateTime? lastUpperLower;
  for (var k = span; k >= 1; k--) {
    final day = DateTime(today.year, today.month, today.day - k);
    if (k <= breakFrom && k >= breakTo) continue;
    // The last days are always trained, so Up next has something recent.
    final skip = k > 3 && random.nextDouble() < 0.12;
    if (k > switchedAt) {
      final index = switch (day.weekday) {
        DateTime.monday || DateTime.thursday => 0,
        DateTime.tuesday || DateTime.friday => 1,
        _ => null,
      };
      if (index == null || skip) continue;
      final (title, plan) = _upperLower[index];
      sessions.add(
        train(day, k, title, plan, splitId: upperLower.id, dayIndex: index),
      );
      lastUpperLower = day;
    } else {
      if (day.weekday == DateTime.thursday || day.weekday == DateTime.sunday) {
        // A free workout now and then, planned as it went.
        if (day.weekday == DateTime.thursday && thursdays++ % 3 == 1) {
          sessions.add(
            train(day, k, 'Arms', const [
              ('Dumbbell Curl', 0, 4, 10, 12),
              ('Triceps Pushdown', 0, 4, 12, null),
            ]),
          );
        }
        continue;
      }
      if (skip) continue;
      final index = rotation % _ppl.length;
      final (title, plan) = _ppl[index];
      sessions.add(
        train(day, k, title, plan, splitId: ppl.id, dayIndex: index),
      );
      rotation++;
    }
  }
  await repo.sessions.putAll(sessions);

  return SampleData(
    exerciseIds: ids,
    currentSplitId: ppl.id,
    previousSplitId: upperLower.id,
    previousSplitUsedAt: lastUpperLower ?? today,
  );
}
