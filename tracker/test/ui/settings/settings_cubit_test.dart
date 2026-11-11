import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/domain/models/effort_scale.dart';
import 'package:tracker/domain/models/graph_config.dart';
import 'package:tracker/domain/models/number_entry.dart';
import 'package:tracker/domain/models/rep_mode.dart';
import 'package:tracker/domain/models/split_draft.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';

import '../../../testing/fakes/in_memory_storage.dart';

void main() {
  group('Setting conversions & state', () {
    test('converts pounds and kilograms at the UI boundary', () {
      expect(WeightUnit.kilograms.fromKilograms(100), 100);
      expect(WeightUnit.pounds.fromKilograms(100), closeTo(220.462, 0.001));
      expect(WeightUnit.pounds.toKilograms(220.46226218), closeTo(100, 0.001));
    });

    test('settings state round-trips persisted preferences', () {
      final state = SettingsState(
        unit: WeightUnit.pounds,
        notificationsEnabled: false,
        analyticsEnabled: false,
      );
      final restored = SettingsState.fromJson(state.toJson());
      expect(restored.unit, WeightUnit.pounds);
      expect(restored.toJson().containsKey('displayName'), isFalse);
      expect(restored.toJson().containsKey('email'), isFalse);
      expect(restored.notificationsEnabled, isFalse);
      expect(restored.analyticsEnabled, isFalse);
    });

    test('malformed settings values use safe defaults', () {
      final state = SettingsState.fromJson({
        'unit': Object(),
        'notificationsEnabled': 'bad',
        'analyticsEnabled': null,
        'freeStartPlacement': Object(),
        'defaultReps': 'bad',
        'defaultRepRangeMin': Object(),
        'defaultRepRangeMax': 0,
        'graphs': [
          null,
          'bad',
          {'title': ''},
        ],
      });
      expect(state, SettingsState());
      expect(
        () => state.graphs.add(const GraphConfig(exerciseId: 1)),
        throwsUnsupportedError,
      );
    });

    test('malformed rep range falls back to the default range', () {
      final crossed = SettingsState.fromJson({
        'defaultRepRangeMin': 15,
        'defaultRepRangeMax': 10,
      });
      expect(
        crossed.defaultRepRangeMin,
        SettingsState.initialDefaultRepRangeMin,
      );
      expect(
        crossed.defaultRepRangeMax,
        SettingsState.initialDefaultRepRangeMax,
      );

      final negative = SettingsState.fromJson({
        'defaultReps': -2,
        'defaultRepRangeMin': -1,
        'defaultRepRangeMax': 12,
      });
      expect(negative.defaultReps, SettingsState.initialDefaultReps);
      expect(
        negative.defaultRepRangeMin,
        SettingsState.initialDefaultRepRangeMin,
      );
    });

    test('persists graphs and their range, ignoring malformed entries', () {
      const graph = GraphConfig(exerciseId: 7, metric: GraphMetric.record1rm);
      final state = SettingsState(
        graphs: [graph],
        graphRange: GraphTimeframe.lastYear,
      );
      final restored = SettingsState.fromJson({
        ...state.toJson(),
        'graphs': [
          ...state.toJson()['graphs'] as List<dynamic>,
          {'metric': 'volume'},
        ],
      });
      expect(restored.graphs, [graph]);
      expect(restored.graphRange, GraphTimeframe.lastYear);
    });

    test('v2 graphs keep their exercise; "All exercises" ones are dropped', () {
      final restored = SettingsState.fromJson({
        'v': 2,
        'graphs': [
          {
            'title': 'Bench progress',
            'exerciseId': 7,
            'metric': 'peakWeight',
            'timeframe': 'last30Days',
          },
          {'title': 'Everything', 'exerciseId': null, 'metric': 'volume'},
        ],
      });
      expect(restored.graphs, [
        const GraphConfig(exerciseId: 7, metric: GraphMetric.peakWeight),
      ]);
      expect(restored.graphRange, GraphTimeframe.last90Days);
    });

    test('an unknown graph range reads as three months', () {
      final restored = SettingsState.fromJson({'v': 3, 'graphRange': 'decade'});
      expect(restored.graphRange, GraphTimeframe.last90Days);
    });

    test('setGraphRange changes the range every graph shows', () {
      HydratedBloc.storage = InMemoryStorage();
      final cubit = SettingsCubit();
      addTearDown(cubit.close);
      cubit.setGraphRange(GraphTimeframe.all);
      expect(cubit.state.graphRange, GraphTimeframe.all);
    });
  });

  group('SettingsState schema versioning', () {
    test('legacy payloads without a version read as v1', () {
      final state = SettingsState.fromJson({
        'unit': 'pounds',
        'notificationsEnabled': false,
      });
      expect(state.unit, WeightUnit.pounds);
      expect(state.notificationsEnabled, isFalse);
    });

    test('payloads without rep defaults fall back to defaults', () {
      final state = SettingsState.fromJson({'unit': 'pounds'});
      expect(state.defaultReps, SettingsState.initialDefaultReps);
      expect(state.defaultRepRangeMin, SettingsState.initialDefaultRepRangeMin);
      expect(state.defaultRepRangeMax, SettingsState.initialDefaultRepRangeMax);
    });

    test('rep defaults round-trip', () {
      final state = SettingsState(
        defaultReps: 5,
        defaultRepRangeMin: 6,
        defaultRepRangeMax: 9,
      );
      final restored = SettingsState.fromJson(state.toJson());
      expect(restored.defaultReps, 5);
      expect(restored.defaultRepRangeMin, 6);
      expect(restored.defaultRepRangeMax, 9);
      expect(restored, state);
    });

    test('versioned payload round-trips with the v field', () {
      final state = SettingsState(
        unit: WeightUnit.pounds,
        notificationsEnabled: false,
      );
      final json = state.toJson();
      expect(json['v'], 3);
      final restored = SettingsState.fromJson(json);
      expect(restored, state);
    });

    test('v2 carries prefill, number entry and the current split', () {
      final state = SettingsState(
        prefillSets: false,
        numberEntry: NumberEntry.steppers,
        currentSplitId: 4,
      );
      final restored = SettingsState.fromJson(state.toJson());
      expect(restored.prefillSets, isFalse);
      expect(restored.numberEntry, NumberEntry.steppers);
      expect(restored.currentSplitId, 4);
      expect(restored, state);
      expect(restored.copyWith(currentSplitId: null).currentSplitId, isNull);
    });

    test('v2 carries the effort scale, RPE by default', () {
      expect(SettingsState().effortScale, EffortScale.rpe);
      final state = SettingsState(effortScale: EffortScale.rir);
      final restored = SettingsState.fromJson(state.toJson());
      expect(restored.effortScale, EffortScale.rir);
      expect(restored, state);
      expect(
        SettingsState.fromJson({'v': 2, 'effortScale': 'borg'}).effortScale,
        EffortScale.rpe,
      );
      expect(SettingsState.fromJson({'v': 1}).effortScale, EffortScale.rpe);
    });

    test('v2 carries when splits were last used and skips junk', () {
      final state = SettingsState(splitsUsedAt: {3: DateTime(2026, 11, 8, 9)});
      final restored = SettingsState.fromJson(state.toJson());
      expect(restored.splitsUsedAt, {3: DateTime(2026, 11, 8, 9)});
      expect(restored, state);
      expect(restored.hashCode, state.hashCode);
      expect(
        SettingsState.fromJson({
          'v': 2,
          'splitsUsedAt': {
            'x': '2026-01-01',
            '4': 'soon',
            '5': 7,
            '6': '2026-02-03T00:00:00.000',
          },
        }).splitsUsedAt,
        {6: DateTime(2026, 2, 3)},
      );
      expect(
        SettingsState.fromJson({'v': 2, 'splitsUsedAt': 'bad'}).splitsUsedAt,
        isEmpty,
      );
    });

    test('v1 payloads read the new logging settings as defaults', () {
      final state = SettingsState.fromJson({
        'v': 1,
        'unit': 'pounds',
        'freeStartPlacement': 'after',
        'numberEntry': 'steppers',
      });
      expect(state.unit, WeightUnit.pounds);
      expect(state.prefillSets, isTrue);
      expect(state.numberEntry, NumberEntry.keypad);
      expect(state.currentSplitId, isNull);
    });

    test('malformed v2 logging settings use safe defaults', () {
      final state = SettingsState.fromJson({
        'v': 2,
        'prefillSets': 'yes',
        'numberEntry': 'abacus',
        'currentSplitId': 'one',
      });
      expect(state.prefillSets, isTrue);
      expect(state.numberEntry, NumberEntry.keypad);
      expect(state.currentSplitId, isNull);
    });

    test('unknown schema version falls back to defaults', () {
      final state = SettingsState.fromJson({
        'v': 99,
        'unit': 'pounds',
        'notificationsEnabled': false,
      });
      expect(state, SettingsState());
      expect(state.unit, WeightUnit.kilograms);
      expect(state.notificationsEnabled, isTrue);
    });
  });

  group('heavy-weight warning preference', () {
    test('is on by default and round-trips when turned off', () {
      expect(SettingsState().showHeavyWeightWarning, isTrue);

      final off = SettingsState(showHeavyWeightWarning: false);
      final restored = SettingsState.fromJson(off.toJson());
      expect(restored.showHeavyWeightWarning, isFalse);
      expect(restored, off);
    });

    test('payloads written before the flag existed keep it on', () {
      final state = SettingsState.fromJson({'v': 1, 'unit': 'pounds'});
      expect(state.showHeavyWeightWarning, isTrue);
    });

    test('a malformed flag falls back to on', () {
      final state = SettingsState.fromJson({
        'v': 1,
        'showHeavyWeightWarning': 'no',
      });
      expect(state.showHeavyWeightWarning, isTrue);
    });

    test('is part of equality and copyWith', () {
      final on = SettingsState();
      final off = on.copyWith(showHeavyWeightWarning: false);
      expect(off.showHeavyWeightWarning, isFalse);
      expect(off == on, isFalse);
      expect(off.copyWith(), off);
    });

    test('heavyWeightConfirmed is off by default and round-trips', () {
      expect(SettingsState().heavyWeightConfirmed, isFalse);

      final confirmed = SettingsState(heavyWeightConfirmed: true);
      final restored = SettingsState.fromJson(confirmed.toJson());
      expect(restored.heavyWeightConfirmed, isTrue);
      expect(restored, confirmed);
    });

    test('a malformed heavyWeightConfirmed falls back to false', () {
      final state = SettingsState.fromJson({
        'v': 1,
        'heavyWeightConfirmed': 'yes',
      });
      expect(state.heavyWeightConfirmed, isFalse);
    });

    test('heavyWeightConfirmed is part of equality and copyWith', () {
      final fresh = SettingsState();
      final confirmed = fresh.copyWith(heavyWeightConfirmed: true);
      expect(confirmed.heavyWeightConfirmed, isTrue);
      expect(confirmed == fresh, isFalse);
      expect(confirmed.copyWith(), confirmed);
    });
  });

  group('current split', () {
    setUp(() => HydratedBloc.storage = InMemoryStorage());

    test('a switch stamps the split it replaces as just used', () {
      var now = DateTime(2026, 11, 8, 10);
      final cubit = SettingsCubit(now: () => now);
      addTearDown(cubit.close);
      final first = DateTime(2026, 11, 8, 10);

      cubit.setCurrentSplit(2, previous: 1);
      expect(cubit.state.currentSplitId, 2);
      expect(cubit.state.splitsUsedAt, {1: first});

      now = now.add(const Duration(minutes: 5));
      cubit.setCurrentSplit(2, previous: 2);
      expect(cubit.state.splitsUsedAt, {1: first}, reason: 'no switch');
      cubit.setCurrentSplit(1, previous: 2);
      expect(cubit.state.splitsUsedAt, {1: first, 2: now});

      cubit.forgetSplit(1);
      expect(cubit.state.currentSplitId, isNull, reason: 'it was current');
      expect(cubit.state.splitsUsedAt, {2: now});
      cubit
        ..setCurrentSplit(3)
        ..forgetSplit(2);
      expect(cubit.state.currentSplitId, 3);
      expect(cubit.state.splitsUsedAt, isEmpty);
    });
  });

  group('default set target', () {
    setUp(() => HydratedBloc.storage = InMemoryStorage());

    test('a range or fixed reps each keep the other kind', () {
      final cubit = SettingsCubit();
      addTearDown(cubit.close);

      cubit.setDefaultSetTarget(const SetTarget(6));
      expect(cubit.state.defaultRepMode, RepMode.fixed);
      expect(cubit.state.defaultReps, 6);
      expect(cubit.state.defaultRepRangeMin, 8, reason: 'range kept');
      expect(cubit.state.defaultRepRangeMax, 12, reason: 'range kept');

      cubit.setDefaultSetTarget(const SetTarget(5, 7));
      expect(cubit.state.defaultRepMode, RepMode.range);
      expect(cubit.state.defaultRepRangeMin, 5);
      expect(cubit.state.defaultRepRangeMax, 7);
      expect(cubit.state.defaultReps, 6, reason: 'fixed reps kept');
    });

    test('ignores targets below one rep or with the max under the min', () {
      final cubit = SettingsCubit();
      addTearDown(cubit.close);
      final before = cubit.state;

      cubit
        ..setDefaultSetTarget(const SetTarget(0))
        ..setDefaultSetTarget(const SetTarget(9, 4));
      expect(cubit.state, before);
    });
  });
}
