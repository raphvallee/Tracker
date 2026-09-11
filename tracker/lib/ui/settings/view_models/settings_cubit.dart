import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/domain/models/graph_config.dart';
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
    List<GraphConfig> graphs = const [],
  }) : graphs = List.unmodifiable(graphs);

  static SettingsState _fromV1(Map<String, dynamic> json) {
    final rawGraphs = json['graphs'];
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
  final List<GraphConfig> graphs;

  SettingsState copyWith({
    WeightUnit? unit,
    bool? notificationsEnabled,
    bool? analyticsEnabled,
    FreeStartPlacement? freeStartPlacement,
    List<GraphConfig>? graphs,
  }) {
    return SettingsState(
      unit: unit ?? this.unit,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      freeStartPlacement: freeStartPlacement ?? this.freeStartPlacement,
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
      _listEquals(graphs, other.graphs);

  @override
  int get hashCode => Object.hash(
    unit,
    notificationsEnabled,
    analyticsEnabled,
    freeStartPlacement,
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
