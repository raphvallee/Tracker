import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/domain/models/graph_config.dart';
import 'package:tracker/domain/models/rep_mode.dart';
import 'package:tracker/domain/models/weight_unit.dart';

class SettingsState {
  factory SettingsState.fromJson(Map<String, dynamic> json) {
    // Hydrated-state schema versioning (PRODUCTION_READINESS.md Phase 1).
    // v1 = the original shape; payloads written before versioning have no
    // 'v' key and read as v1. Unknown future versions fall back to defaults
    // instead of crashing.
    switch (json['v'] as int? ?? 1) {
      case 1:
        return _fromV1(json);
      default:
        return SettingsState();
    }
  }

  SettingsState({
    this.unit = WeightUnit.kilograms,
    this.notificationsEnabled = true,
    this.analyticsEnabled = true,
    this.freeStartPlacement = FreeStartPlacement.before,
    this.defaultRepMode = initialDefaultRepMode,
    this.defaultReps = initialDefaultReps,
    this.defaultRepRangeMin = initialDefaultRepRangeMin,
    this.defaultRepRangeMax = initialDefaultRepRangeMax,
    List<GraphConfig> graphs = const [],
  }) : graphs = List.unmodifiable(graphs);

  /// Mode used for newly created planned sets. The app bundles with
  /// [RepMode.range].
  static const RepMode initialDefaultRepMode = RepMode.range;

  /// Default rep count pre-filled when adding a fixed set in the split editor.
  static const int initialDefaultReps = 10;

  /// Default rep-range bounds pre-filled when adding a range set.
  static const int initialDefaultRepRangeMin = 8;
  static const int initialDefaultRepRangeMax = 12;

  static int? _positiveInt(Object? value) =>
      value is int && value > 0 ? value : null;

  /// Reads a persisted rep-range pair, falling back to the defaults when
  /// either bound is missing/malformed or the range is crossed (min > max).
  static (int, int) _repRange(Map<String, dynamic> json) {
    final min = _positiveInt(json['defaultRepRangeMin']);
    final max = _positiveInt(json['defaultRepRangeMax']);
    if (min == null || max == null || min > max) {
      return (initialDefaultRepRangeMin, initialDefaultRepRangeMax);
    }
    return (min, max);
  }

  static SettingsState _fromV1(Map<String, dynamic> json) {
    final rawGraphs = json['graphs'];
    final (rangeMin, rangeMax) = _repRange(json);
    return SettingsState(
      unit: WeightUnit.values.asNameMap()[json['unit']] ?? WeightUnit.kilograms,
      notificationsEnabled: json['notificationsEnabled'] is bool
          ? json['notificationsEnabled'] as bool
          : true,
      analyticsEnabled: json['analyticsEnabled'] is bool
          ? json['analyticsEnabled'] as bool
          : true,
      freeStartPlacement:
          FreeStartPlacement.values.asNameMap()[json['freeStartPlacement']] ??
          FreeStartPlacement.before,
      defaultRepMode:
          RepMode.values.asNameMap()[json['defaultRepMode']] ?? RepMode.range,
      defaultReps: _positiveInt(json['defaultReps']) ?? initialDefaultReps,
      defaultRepRangeMin: rangeMin,
      defaultRepRangeMax: rangeMax,
      graphs: rawGraphs is List
          ? rawGraphs
                .whereType<Map>()
                .map((entry) {
                  try {
                    return GraphConfig.fromJson(
                      Map<String, dynamic>.from(entry),
                    );
                  } catch (_) {
                    return null;
                  }
                })
                .whereType<GraphConfig>()
                .toList()
          : const [],
    );
  }

  final WeightUnit unit;
  final bool notificationsEnabled;
  final bool analyticsEnabled;
  final FreeStartPlacement freeStartPlacement;

  /// Rep defaults pre-filled when adding sets in the split editor.
  final RepMode defaultRepMode;
  final int defaultReps;
  final int defaultRepRangeMin;
  final int defaultRepRangeMax;

  final List<GraphConfig> graphs;

  SettingsState copyWith({
    WeightUnit? unit,
    bool? notificationsEnabled,
    bool? analyticsEnabled,
    FreeStartPlacement? freeStartPlacement,
    RepMode? defaultRepMode,
    int? defaultReps,
    int? defaultRepRangeMin,
    int? defaultRepRangeMax,
    List<GraphConfig>? graphs,
  }) {
    return SettingsState(
      unit: unit ?? this.unit,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      freeStartPlacement: freeStartPlacement ?? this.freeStartPlacement,
      defaultRepMode: defaultRepMode ?? this.defaultRepMode,
      defaultReps: defaultReps ?? this.defaultReps,
      defaultRepRangeMin: defaultRepRangeMin ?? this.defaultRepRangeMin,
      defaultRepRangeMax: defaultRepRangeMax ?? this.defaultRepRangeMax,
      graphs: graphs ?? this.graphs,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SettingsState &&
      unit == other.unit &&
      notificationsEnabled == other.notificationsEnabled &&
      analyticsEnabled == other.analyticsEnabled &&
      freeStartPlacement == other.freeStartPlacement &&
      defaultRepMode == other.defaultRepMode &&
      defaultReps == other.defaultReps &&
      defaultRepRangeMin == other.defaultRepRangeMin &&
      defaultRepRangeMax == other.defaultRepRangeMax &&
      _listEquals(graphs, other.graphs);

  @override
  int get hashCode => Object.hash(
    unit,
    notificationsEnabled,
    analyticsEnabled,
    freeStartPlacement,
    defaultRepMode,
    defaultReps,
    defaultRepRangeMin,
    defaultRepRangeMax,
    Object.hashAll(graphs),
  );

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Map<String, dynamic> toJson() => {
    // Hydrated-state schema version; see the comment on fromJson.
    'v': 1,
    'unit': unit.name,
    'notificationsEnabled': notificationsEnabled,
    'analyticsEnabled': analyticsEnabled,
    'freeStartPlacement': freeStartPlacement.name,
    'defaultRepMode': defaultRepMode.name,
    'defaultReps': defaultReps,
    'defaultRepRangeMin': defaultRepRangeMin,
    'defaultRepRangeMax': defaultRepRangeMax,
    'graphs': graphs.map((graph) => graph.toJson()).toList(),
  };
}

class SettingsCubit extends HydratedCubit<SettingsState> {
  SettingsCubit() : super(SettingsState());

  void setUnit(WeightUnit unit) => emit(state.copyWith(unit: unit));

  void setNotificationsEnabled(bool value) =>
      emit(state.copyWith(notificationsEnabled: value));

  void setAnalyticsEnabled(bool value) =>
      emit(state.copyWith(analyticsEnabled: value));

  void setFreeStartPlacement(FreeStartPlacement placement) =>
      emit(state.copyWith(freeStartPlacement: placement));

  /// Sets the default rep mode used for newly created sets.
  void setDefaultRepMode(RepMode mode) =>
      emit(state.copyWith(defaultRepMode: mode));

  /// Sets the default rep count pre-filled for fixed sets (minimum 1).
  void setDefaultReps(int reps) {
    if (reps < 1) return;
    emit(state.copyWith(defaultReps: reps));
  }

  /// Sets the default rep range pre-filled for range sets.
  /// Ignored unless `1 <= min <= max`.
  void setDefaultRepRange({required int min, required int max}) {
    if (min < 1 || max < min) return;
    emit(state.copyWith(defaultRepRangeMin: min, defaultRepRangeMax: max));
  }

  void addGraph(GraphConfig graph) =>
      emit(state.copyWith(graphs: [...state.graphs, graph]));

  void updateGraph(int index, GraphConfig graph) {
    if (index < 0 || index >= state.graphs.length) return;
    final graphs = [...state.graphs]..[index] = graph;
    emit(state.copyWith(graphs: graphs));
  }

  void removeGraph(int index) {
    if (index < 0 || index >= state.graphs.length) return;
    final graphs = [...state.graphs]..removeAt(index);
    emit(state.copyWith(graphs: graphs));
  }

  @override
  SettingsState? fromJson(Map<String, dynamic> json) =>
      SettingsState.fromJson(json);

  @override
  Map<String, dynamic>? toJson(SettingsState state) => state.toJson();

  static SettingsCubit? maybeOf(BuildContext context) {
    try {
      return context.read<SettingsCubit>();
    } on ProviderNotFoundException {
      return null;
    }
  }
}
