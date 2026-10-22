// Unit tests for settings (lib/pages/settings/) - pure: weight unit conversion
// and SettingsState JSON round-trip. The SettingsCubit (HydratedCubit) and
// SettingsPage widget are integration tests: test/integration/settings_test.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/models/graph_config.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';

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
        () => state.graphs.add(const GraphConfig(title: 'x')),
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

    test('persists graph configurations and ignores malformed entries', () {
      const graph = GraphConfig(
        title: 'Bench progress',
        exerciseId: 7,
        metric: GraphMetric.peakWeight,
        timeframe: GraphTimeframe.last90Days,
      );
      final state = SettingsState(graphs: [graph]);
      final restored = SettingsState.fromJson({
        ...state.toJson(),
        'graphs': [
          ...state.toJson()['graphs'] as List<dynamic>,
          {'title': ''},
        ],
      });
      expect(restored.graphs, hasLength(1));
      expect(restored.graphs.single.title, 'Bench progress');
      expect(restored.graphs.single.metric, GraphMetric.peakWeight);
      expect(restored.graphs.single.timeframe, GraphTimeframe.last90Days);
    });

    test('graph config supports clearing exercise filter', () {
      const graph = GraphConfig(title: 'x', exerciseId: 2);
      expect(graph.copyWith(exerciseId: null).exerciseId, isNull);
      expect(GraphConfig.fromJson(graph.toJson()).exerciseId, 2);
    });

    test('collections and values have structural equality', () {
      const graph = GraphConfig(title: 'x');
      expect(SettingsState(graphs: [graph]), SettingsState(graphs: [graph]));
      expect(
        () => SettingsState(graphs: [graph]).graphs.add(graph),
        throwsUnsupportedError,
      );
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
      expect(json['v'], 1);
      final restored = SettingsState.fromJson(json);
      expect(restored, state);
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
}
