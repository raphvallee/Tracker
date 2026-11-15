import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/muscle.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/services/gym_equivalence.dart';
import 'package:tracker/domain/services/set_prefill.dart';

const _home = 1;
const _hotel = 2;
const _legPress = 10;

final _start = DateTime(2026, 1, 1);

WorkoutSession _session(
  int day,
  int gymId,
  double weight, {
  double reps = 10,
  double? rpe,
  int exerciseId = _legPress,
  SetType type = SetType.working,
}) => WorkoutSession(
  startTime: _start.add(Duration(days: day)),
  gymId: gymId,
  sets: [
    WorkoutSet(
      exerciseId: exerciseId,
      weight: weight,
      reps: reps,
      type: type,
      rpe: rpe,
    ),
  ],
);

/// A lifter getting stronger by [perDay] kg a day at home, training at the
/// hotel gym (where machines read 10% heavy) on [hotelDays].
List<WorkoutSession> _progressing({
  required List<int> homeDays,
  required List<int> hotelDays,
  double from = 150,
  double perDay = 0.5,
  double hotelFactor = 0.9,
}) => [
  for (final day in homeDays) _session(day, _home, from + perDay * day),
  for (final day in hotelDays)
    _session(day, _hotel, (from + perDay * day) / hotelFactor),
];

Gym _gym(
  int id, {
  bool primary = false,
  double multiplier = 1,
  List<GymExerciseMultiplier> rows = const [],
}) => Gym(
  name: 'Gym $id',
  isPrimary: primary,
  multiplier: multiplier,
  perExerciseMultipliers: rows,
)..id = id;

Exercise _exercise(int id, Equipment equipment) => Exercise(
  title: 'Exercise $id',
  primaryMuscle: [Muscle.values.first],
  equipment: [equipment],
  movementPattern: MovementPattern.unspecified,
)..id = id;

void main() {
  group('convertsAcrossGyms', () {
    test('machines and cables convert, plates and dumbbells do not', () {
      expect(convertsAcrossGyms([Equipment.machine]), isTrue);
      expect(convertsAcrossGyms([Equipment.cable]), isTrue);
      expect(convertsAcrossGyms([Equipment.barbell]), isFalse);
      expect(convertsAcrossGyms([Equipment.dumbbell]), isFalse);
      expect(convertsAcrossGyms([Equipment.bodyweight]), isFalse);
      expect(
        convertsAcrossGyms([Equipment.barbell, Equipment.machine]),
        isTrue,
      );
    });
  });

  group('estimateExerciseFactor', () {
    FactorEstimate? estimate(
      List<WorkoutSession> sessions, {
      DateTime? now,
      bool effectiveReps = false,
    }) => estimateExerciseFactor(
      sessions,
      exerciseId: _legPress,
      homeGymId: _home,
      gymId: _hotel,
      now: now,
      effectiveReps: effectiveReps,
    );

    test('with effective reps, going easier away is no heavier machine', () {
      // Sets of 10 at home at RPE 9, and at the hotel (machines 10% heavy)
      // at RPE 7, so with 3 left instead of 1: the same lifter, on an
      // unfamiliar machine.
      final hotel = 150 * (1 + 11 / 30) / ((1 + 13 / 30) * 0.9);
      final sessions = [
        for (var day = 0; day <= 60; day += 3)
          _session(day, _home, 150, rpe: 9),
        _session(20, _hotel, hotel, rpe: 7),
        _session(40, _hotel, hotel, rpe: 7),
      ];
      // Weight and reps alone read the easier sets as a heavier machine.
      expect(estimate(sessions)!.factor, closeTo(150 / hotel, 0.001));
      expect(
        estimate(sessions, effectiveReps: true)!.factor,
        closeTo(0.9, 0.001),
      );
    });

    test('effective reps keep a set without a rating as logged', () {
      final sessions = [
        _session(0, _home, 100, rpe: 8),
        _session(1, _hotel, 100),
      ];
      expect(
        estimate(sessions, effectiveReps: true)!.factor,
        closeTo((1 + 12 / 30) / (1 + 10 / 30), 0.001),
      );
    });

    test('measures the gym against the trend, so progress is no bias', () {
      // Hotel visits early on, when weaker, and late, when stronger: a mean
      // of weights would mix both; the trend sets each against its day.
      final result = estimate(
        _progressing(
          homeDays: [for (var d = 0; d <= 120; d += 3) d],
          hotelDays: [10, 20, 100, 115],
        ),
      );
      expect(result, isNotNull);
      expect(result!.factor, closeTo(0.9, 0.01));
      expect(result.samples, 4);
      expect(result.spread, lessThan(0.01));
    });

    test('carries the trend past the last home workout', () {
      // Two weeks after the last home workout the lifter is stronger still.
      final result = estimate(
        _progressing(
          homeDays: [for (var d = 0; d <= 90; d += 3) d],
          hotelDays: [104],
        ),
      );
      expect(result!.factor, closeTo(0.9, 0.01));
    });

    test('compares estimated 1RMs, so reps count', () {
      final result = estimate([
        _session(0, _home, 100, reps: 10),
        _session(1, _hotel, 100, reps: 5),
      ]);
      // 100 × 10 at home is a bigger lift than 100 × 5 at the hotel.
      expect(result!.factor, closeTo((1 + 10 / 30) / (1 + 5 / 30), 0.001));
    });

    test('leaves out warm-ups, and a weight off by ten', () {
      final result = estimate([
        _session(0, _home, 100),
        _session(1, _hotel, 500, type: SetType.warmup),
        _session(2, _hotel, 1100),
        _session(3, _hotel, 110),
      ]);
      expect(result!.factor, closeTo(100 / 110, 0.001));
      expect(result.samples, 1);
    });

    test('takes the median, so one odd workout does not move it', () {
      final result = estimate([
        for (var d = 0; d < 30; d += 2) _session(d, _home, 100),
        _session(1, _hotel, 110),
        _session(5, _hotel, 111),
        _session(9, _hotel, 109),
        _session(13, _hotel, 140),
      ]);
      expect(result!.factor, closeTo(100 / 110, 0.01));
    });

    test('recent workouts weigh more', () {
      final result = estimate([
        for (var d = 0; d <= 400; d += 4) _session(d, _home, 100),
        _session(2, _hotel, 125),
        _session(398, _hotel, 110),
      ], now: _start.add(const Duration(days: 400)));
      expect(result!.factor, closeTo(100 / 110, 0.001));
    });

    test('is null without a workout at both gyms near each other', () {
      expect(estimate([_session(0, _home, 100)]), isNull);
      expect(estimate([_session(0, _hotel, 100)]), isNull);
      expect(
        estimate([_session(0, _home, 100), _session(400, _hotel, 110)]),
        isNull,
      );
    });
  });

  group('gymFactorOf', () {
    test('home is 1; else set by hand, the estimate, or the gym', () {
      expect(
        gymFactorOf(_gym(_home, primary: true), _legPress).source,
        FactorSource.home,
      );
      final hotel = _gym(
        _hotel,
        multiplier: 0.95,
        rows: [
          GymExerciseMultiplier(
            exerciseId: _legPress,
            multiplier: 0.9,
            estimate: 0.9,
            samples: 6,
            spread: 0.02,
          ),
          GymExerciseMultiplier(
            exerciseId: 11,
            multiplier: 1.1,
            manual: true,
            estimate: 1.05,
          ),
        ],
      );
      final estimated = gymFactorOf(hotel, _legPress);
      expect(estimated.value, 0.9);
      expect(estimated.source, FactorSource.estimated);
      expect(estimated.samples, 6);
      final manual = gymFactorOf(hotel, 11);
      expect(manual.value, 1.1);
      expect(manual.source, FactorSource.manual);
      expect(manual.estimate, 1.05);
      final overall = gymFactorOf(hotel, 12);
      expect(overall.value, 0.95);
      expect(overall.source, FactorSource.gym);
    });

    test('an older row without an estimate reads as one', () {
      final factor = gymFactorOf(
        _gym(
          _hotel,
          rows: [GymExerciseMultiplier(exerciseId: _legPress, multiplier: 0.8)],
        ),
        _legPress,
      );
      expect(factor.source, FactorSource.estimated);
      expect(factor.estimate, 0.8);
    });

    test('the band narrows with more workouts and is none by hand', () {
      expect(GymFactor.home.band, 0);
      expect(const GymFactor(0.9, FactorSource.manual).band, 0);
      expect(
        const GymFactor(0.9, FactorSource.estimated, samples: 1).band,
        greaterThan(
          const GymFactor(0.9, FactorSource.estimated, samples: 9).band,
        ),
      );
      expect(
        const GymFactor(
          0.9,
          FactorSource.estimated,
          samples: 4,
          spread: 0.2,
        ).band,
        0.2,
      );
    });
  });

  group('machineFactors', () {
    test('lists machines and cables at every gym but home', () {
      final factors = machineFactors(
        [
          _gym(_home, primary: true),
          _gym(
            _hotel,
            multiplier: 0.95,
            rows: [GymExerciseMultiplier(exerciseId: 1, multiplier: 0.9)],
          ),
        ],
        [
          _exercise(1, Equipment.machine),
          _exercise(2, Equipment.cable),
          _exercise(3, Equipment.barbell),
        ],
      );
      expect(factors, {
        _hotel: {1: 0.9, 2: 0.95},
      });
    });
  });

  group('GymConversion', () {
    final home = _gym(_home, primary: true);
    final hotel = _gym(
      _hotel,
      rows: [
        GymExerciseMultiplier(
          exerciseId: _legPress,
          multiplier: 0.9,
          estimate: 0.9,
          samples: 6,
          spread: 0.02,
        ),
      ],
    );
    final coast = _gym(3, multiplier: 1.1);
    final gyms = [home, hotel, coast];

    GymConversion? conversion(int from, int to, {bool converts = true}) =>
        gymConversionOf(
          converts: converts,
          gyms: gyms,
          exerciseId: _legPress,
          fromGymId: from,
          toGymId: to,
        );

    test('carries weights between gyms by their factors', () {
      expect(conversion(_home, _hotel)!.convert(180), closeTo(200, 0.001));
      expect(conversion(_hotel, _home)!.convert(200), closeTo(180, 0.001));
      expect(conversion(_hotel, 3)!.convert(110), closeTo(90, 0.001));
    });

    test('hangs on the gym away from home', () {
      expect(conversion(_home, _hotel)!.basisGym, hotel);
      expect(conversion(_hotel, _home)!.basisGym, hotel);
      expect(conversion(_hotel, 3)!.basisGym, coast);
    });

    test('is null for plates, the same gym, or an unknown one', () {
      expect(conversion(_home, _hotel, converts: false), isNull);
      expect(conversion(_hotel, _hotel), isNull);
      expect(conversion(_home, 99), isNull);
      expect(
        gymConversionOf(
          converts: true,
          gyms: gyms,
          exerciseId: _legPress,
          fromGymId: null,
          toGymId: _hotel,
        ),
        isNull,
      );
    });

    test('the likely range brackets the guess', () {
      final range = conversion(_home, _hotel)!.rangeOf(180);
      expect(range.low, lessThan(200));
      expect(range.high, greaterThan(200));
    });

    test('a pair of weights that feel the same gives the factor', () {
      expect(
        conversion(
          _home,
          _hotel,
        )!.factorFor(fromKilograms: 180, toKilograms: 200),
        closeTo(0.9, 0.001),
      );
      // At home now, last at the hotel: the hotel's factor still comes out.
      expect(
        conversion(
          _hotel,
          _home,
        )!.factorFor(fromKilograms: 200, toKilograms: 180),
        closeTo(0.9, 0.001),
      );
    });
  });

  group('roundToLoad', () {
    test('rounds to 2.5 kg, or to 5 lb', () {
      expect(roundToLoad(88.9, WeightUnit.kilograms), 90);
      expect(roundToLoad(196.4, WeightUnit.kilograms), 197.5);
      final pounds = roundToLoad(100, WeightUnit.pounds);
      expect(WeightUnit.pounds.fromKilograms(pounds), closeTo(220, 0.0001));
    });
  });

  group('refreshedFactors', () {
    final sessions = _progressing(
      homeDays: [for (var d = 0; d <= 60; d += 3) d],
      hotelDays: [20, 40],
    );

    test('keeps a factor set by hand and learns the estimate beside it', () {
      final hotel = _gym(
        _hotel,
        rows: [
          GymExerciseMultiplier(
            exerciseId: _legPress,
            multiplier: 1.2,
            manual: true,
          ),
        ],
      );
      final rows = refreshedFactors(
        hotel,
        sessions,
        homeGymId: _home,
        exerciseIds: [_legPress],
      );
      expect(rows, hasLength(1));
      expect(rows.single.manual, isTrue);
      expect(rows.single.multiplier, 1.2);
      expect(rows.single.estimate, closeTo(0.9, 0.01));
      expect(rows.single.samples, 2);
    });

    test('replaces an estimate and drops one with nothing behind it', () {
      final hotel = _gym(
        _hotel,
        rows: [
          GymExerciseMultiplier(exerciseId: _legPress, multiplier: 0.5),
          GymExerciseMultiplier(exerciseId: 11, multiplier: 0.7),
        ],
      );
      final rows = refreshedFactors(
        hotel,
        sessions,
        homeGymId: _home,
        exerciseIds: [_legPress, 11],
      );
      expect(rows.map((row) => row.exerciseId), [_legPress]);
      expect(rows.single.multiplier, closeTo(0.9, 0.01));
      expect(overallFactorOf(rows), closeTo(0.9, 0.01));
    });
  });

  group('factors set by hand', () {
    test('set one, keep the estimate, go back to it', () {
      final rows = [
        GymExerciseMultiplier(
          exerciseId: _legPress,
          multiplier: 0.88,
          estimate: 0.88,
          samples: 6,
        ),
      ];
      final manual = withManualFactor(rows, _legPress, 0.9);
      expect(manual.single.manual, isTrue);
      expect(manual.single.multiplier, 0.9);
      expect(manual.single.estimate, 0.88);
      final back = withoutManualFactor(manual, _legPress);
      expect(back.single.manual, isFalse);
      expect(back.single.multiplier, 0.88);
      expect(back.single.samples, 6);
    });

    test('without an estimate, going back leaves the gym\'s factor', () {
      final manual = withManualFactor(const [], _legPress, 0.9);
      expect(withoutManualFactor(manual, _legPress), isEmpty);
    });
  });

  group('rebasedOn', () {
    test('measures every factor against the new primary gym', () {
      final home = _gym(_home, primary: true);
      final hotel = _gym(
        _hotel,
        multiplier: 0.9,
        rows: [
          GymExerciseMultiplier(
            exerciseId: _legPress,
            multiplier: 0.8,
            manual: true,
          ),
        ],
      );
      final coast = _gym(
        3,
        multiplier: 1.2,
        rows: [GymExerciseMultiplier(exerciseId: _legPress, multiplier: 1.1)],
      );
      rebasedOn([home, hotel, coast], 3);
      expect(coast.isPrimary, isTrue);
      expect(coast.multiplier, 1);
      expect(home.isPrimary, isFalse);
      expect(home.multiplier, closeTo(1 / 1.2, 0.0001));
      expect(hotel.multiplier, closeTo(0.9 / 1.2, 0.0001));
      expect(
        hotel.perExerciseMultipliers.single.multiplier,
        closeTo(0.8 / 1.1, 0.0001),
      );
    });
  });

  group('setup notes', () {
    test('set, replace and clear a machine\'s note', () {
      final gym = _gym(_hotel);
      gym.machineSetups = withSetupNote(
        gym.machineSetups,
        _legPress,
        ' Seat 4 ',
      );
      expect(setupNoteOf(gym, _legPress), 'Seat 4');
      gym.machineSetups = withSetupNote(gym.machineSetups, _legPress, 'Seat 5');
      expect(gym.machineSetups, hasLength(1));
      expect(setupNoteOf(gym, _legPress), 'Seat 5');
      gym.machineSetups = withSetupNote(gym.machineSetups, _legPress, '  ');
      expect(setupNoteOf(gym, _legPress), isNull);
    });
  });

  group('gym trend', () {
    test('brings workouts elsewhere home onto the trend', () {
      final sessions = _progressing(
        homeDays: [for (var d = 0; d <= 60; d += 3) d],
        hotelDays: [31],
      );
      final gyms = [
        _gym(_home, primary: true),
        _gym(
          _hotel,
          rows: [GymExerciseMultiplier(exerciseId: _legPress, multiplier: 0.9)],
        ),
      ];
      final points = gymTrendOf(sessions, _legPress, gyms);
      expect(points, hasLength(22));
      final away = points.singleWhere((point) => point.gymId == _hotel);
      final trend = homeTrendAt(points, _home, away.date)!;
      expect(away.atHome, closeTo(trend, trend * 0.01));
      expect(away.logged, greaterThan(away.atHome));
    });
  });

  group('prefill at another gym', () {
    test('withWeights converts every set and keeps the rest', () {
      final previous = PreviousPerformance(
        date: _start,
        gymId: _home,
        sets: [
          WorkoutSet(
            exerciseId: _legPress,
            weight: 90,
            reps: 12,
            type: SetType.warmup,
          ),
          WorkoutSet(exerciseId: _legPress, weight: 180, reps: 10, rpe: 8),
        ],
      );
      final converted = previous.withWeights((kg) => kg * 2);
      expect(converted.sets.map((set) => set.weight), [180, 360]);
      expect(converted.sets.first.isWarmup, isTrue);
      expect(converted.sets.last.rpe, 8);
      expect(converted.gymId, _home);
    });

    test('the latest logged working set sets how far the rest move', () {
      final last = [
        WorkoutSet(weight: 100, reps: 12, type: SetType.warmup),
        WorkoutSet(weight: 200, reps: 10),
        WorkoutSet(weight: 200, reps: 10),
      ];
      expect(
        loggedCorrection([
          (weight: 120, reps: 12, rpe: null, warmup: true),
        ], last),
        1,
      );
      expect(
        loggedCorrection([
          (weight: 100, reps: 12, rpe: null, warmup: true),
          (weight: 210, reps: 10, rpe: 6, warmup: false),
        ], last),
        closeTo(1.05, 0.0001),
      );
      expect(
        loggedCorrection([
          (weight: 100, reps: 12, rpe: null, warmup: true),
          (weight: 2000, reps: 10, rpe: null, warmup: false),
        ], last),
        2,
      );
      expect(loggedCorrection(const [], last), 1);
    });

    test('with effective reps, a set rated very easy or very hard moves '
        'the rest too', () {
      final last = [
        WorkoutSet(weight: 100, reps: 12, type: SetType.warmup),
        WorkoutSet(weight: 200, reps: 10),
        WorkoutSet(weight: 200, reps: 10, rpe: 9),
      ];
      const warmup = (weight: 100.0, reps: 12.0, rpe: null, warmup: true);
      double correction(double weight, double? rpe, {int row = 1}) =>
          loggedCorrection(
            [
              warmup,
              for (var i = 1; i <= row; i++)
                (weight: weight, reps: 10.0, rpe: rpe, warmup: false),
            ],
            last,
            effectiveReps: true,
          );
      // RPE 6 where an unrated set is taken as 8: 14 reps against 12.
      expect(
        correction(210, 6),
        closeTo(1.05 * (1 + 14 / 30) / (1 + 12 / 30), 0.0001),
      );
      // A usual day moves nothing past the weight.
      expect(correction(210, 8), closeTo(1.05, 0.0001));
      expect(correction(200, null), 1);
      // Taken to failure where last time had one left.
      expect(
        correction(200, 10, row: 2),
        closeTo((1 + 10 / 30) / (1 + 11 / 30), 0.0001),
      );
    });
  });
}
