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
}
