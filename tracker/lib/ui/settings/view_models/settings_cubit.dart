import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/domain/models/graph_config.dart';
import 'package:tracker/domain/models/number_entry.dart';
import 'package:tracker/domain/models/rep_mode.dart';
import 'package:tracker/domain/models/weight_unit.dart';

class SettingsState {
  factory SettingsState.fromJson(Map<String, dynamic> json) {
    // Hydrated-state schema versioning (PRODUCTION_READINESS.md Phase 1).
    // v1 = the original shape; v2 adds set prefill, number entry, the
    // current split and when splits were last picked. Payloads written before versioning have no 'v' key and
    // read as v1. Unknown future versions fall back to defaults instead of
    // crashing.
    switch (json['v'] as int? ?? 1) {
      case 1:
        return _fromV1(json);
      case 2:
        return _fromV2(json);
      default:
        return SettingsState();
    }
  }

  SettingsState({
    this.unit = WeightUnit.kilograms,
    this.notificationsEnabled = true,
    this.analyticsEnabled = true,
    this.prefillSets = true,
    this.numberEntry = NumberEntry.keypad,
    this.currentSplitId,
    Map<int, DateTime> splitsUsedAt = const {},
    this.defaultRepMode = initialDefaultRepMode,
    this.defaultReps = initialDefaultReps,
    this.defaultRepRangeMin = initialDefaultRepRangeMin,
    this.defaultRepRangeMax = initialDefaultRepRangeMax,
    this.showHeavyWeightWarning = true,
    this.heavyWeightConfirmed = false,
    List<GraphConfig> graphs = const [],
  }) : splitsUsedAt = Map.unmodifiable(splitsUsedAt),
       graphs = List.unmodifiable(graphs);

  static const RepMode initialDefaultRepMode = RepMode.range;

  static const int initialDefaultReps = 10;

  static const int initialDefaultRepRangeMin = 8;
  static const int initialDefaultRepRangeMax = 12;

  static int? _positiveInt(Object? value) =>
      value is int && value > 0 ? value : null;

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
      defaultRepMode:
          RepMode.values.asNameMap()[json['defaultRepMode']] ?? RepMode.range,
      defaultReps: _positiveInt(json['defaultReps']) ?? initialDefaultReps,
      defaultRepRangeMin: rangeMin,
      defaultRepRangeMax: rangeMax,
      showHeavyWeightWarning: json['showHeavyWeightWarning'] is bool
          ? json['showHeavyWeightWarning'] as bool
          : true,
      heavyWeightConfirmed: json['heavyWeightConfirmed'] is bool
          ? json['heavyWeightConfirmed'] as bool
          : false,
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

  static SettingsState _fromV2(Map<String, dynamic> json) =>
      _fromV1(json).copyWith(
        prefillSets: json['prefillSets'] is bool
            ? json['prefillSets'] as bool
            : true,
        numberEntry:
            NumberEntry.values.asNameMap()[json['numberEntry']] ??
            NumberEntry.keypad,
        currentSplitId: json['currentSplitId'] is int
            ? json['currentSplitId'] as int
            : null,
        splitsUsedAt: _splitsUsedAt(json['splitsUsedAt']),
      );

  static Map<int, DateTime> _splitsUsedAt(Object? json) {
    if (json is! Map) return const {};
    return {
      for (final MapEntry(:key, :value) in json.entries)
        if (int.tryParse('$key') case final id?)
          if (value is String) id: ?DateTime.tryParse(value),
    };
  }

  final WeightUnit unit;
  final bool notificationsEnabled;
  final bool analyticsEnabled;

  /// Pending set rows show last session's values (or the plan's target reps)
  /// as grey placeholders that one tap logs.
  final bool prefillSets;
  final NumberEntry numberEntry;

  /// The split whose next day the Workout tab offers; null follows the most
  /// recently trained split.
  final int? currentSplitId;

  /// When splits (by id) stopped being current. With the sessions' training
  /// times this orders the Splits tab by last use (see `splitsByLastUsed`).
  final Map<int, DateTime> splitsUsedAt;

  final RepMode defaultRepMode;
  final int defaultReps;
  final int defaultRepRangeMin;
  final int defaultRepRangeMax;

  final bool showHeavyWeightWarning;

  final bool heavyWeightConfirmed;

  final List<GraphConfig> graphs;

  SettingsState copyWith({
    WeightUnit? unit,
    bool? notificationsEnabled,
    bool? analyticsEnabled,
    bool? prefillSets,
    NumberEntry? numberEntry,
    Object? currentSplitId = _unset,
    Map<int, DateTime>? splitsUsedAt,
    RepMode? defaultRepMode,
    int? defaultReps,
    int? defaultRepRangeMin,
    int? defaultRepRangeMax,
    bool? showHeavyWeightWarning,
    bool? heavyWeightConfirmed,
    List<GraphConfig>? graphs,
  }) {
    return SettingsState(
      unit: unit ?? this.unit,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      prefillSets: prefillSets ?? this.prefillSets,
      numberEntry: numberEntry ?? this.numberEntry,
      currentSplitId: identical(currentSplitId, _unset)
          ? this.currentSplitId
          : currentSplitId as int?,
      splitsUsedAt: splitsUsedAt ?? this.splitsUsedAt,
      defaultRepMode: defaultRepMode ?? this.defaultRepMode,
      defaultReps: defaultReps ?? this.defaultReps,
      defaultRepRangeMin: defaultRepRangeMin ?? this.defaultRepRangeMin,
      defaultRepRangeMax: defaultRepRangeMax ?? this.defaultRepRangeMax,
      showHeavyWeightWarning:
          showHeavyWeightWarning ?? this.showHeavyWeightWarning,
      heavyWeightConfirmed: heavyWeightConfirmed ?? this.heavyWeightConfirmed,
      graphs: graphs ?? this.graphs,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SettingsState &&
      unit == other.unit &&
      notificationsEnabled == other.notificationsEnabled &&
      analyticsEnabled == other.analyticsEnabled &&
      prefillSets == other.prefillSets &&
      numberEntry == other.numberEntry &&
      currentSplitId == other.currentSplitId &&
      _mapEquals(splitsUsedAt, other.splitsUsedAt) &&
      defaultRepMode == other.defaultRepMode &&
      defaultReps == other.defaultReps &&
      defaultRepRangeMin == other.defaultRepRangeMin &&
      defaultRepRangeMax == other.defaultRepRangeMax &&
      showHeavyWeightWarning == other.showHeavyWeightWarning &&
      heavyWeightConfirmed == other.heavyWeightConfirmed &&
      _listEquals(graphs, other.graphs);

  @override
  int get hashCode => Object.hash(
    unit,
    notificationsEnabled,
    analyticsEnabled,
    prefillSets,
    numberEntry,
    currentSplitId,
    Object.hashAllUnordered(
      splitsUsedAt.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    defaultRepMode,
    defaultReps,
    defaultRepRangeMin,
    defaultRepRangeMax,
    showHeavyWeightWarning,
    heavyWeightConfirmed,
    Object.hashAll(graphs),
  );

  static const _unset = Object();

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
    if (a.length != b.length) return false;
    for (final MapEntry(:key, :value) in a.entries) {
      if (!b.containsKey(key) || b[key] != value) return false;
    }
    return true;
  }

  Map<String, dynamic> toJson() => {
    'v': 2,
    'unit': unit.name,
    'notificationsEnabled': notificationsEnabled,
    'analyticsEnabled': analyticsEnabled,
    'prefillSets': prefillSets,
    'numberEntry': numberEntry.name,
    'currentSplitId': currentSplitId,
    'splitsUsedAt': {
      for (final MapEntry(:key, :value) in splitsUsedAt.entries)
        '$key': value.toIso8601String(),
    },
    'defaultRepMode': defaultRepMode.name,
    'defaultReps': defaultReps,
    'defaultRepRangeMin': defaultRepRangeMin,
    'defaultRepRangeMax': defaultRepRangeMax,
    'showHeavyWeightWarning': showHeavyWeightWarning,
    'heavyWeightConfirmed': heavyWeightConfirmed,
    'graphs': graphs.map((graph) => graph.toJson()).toList(),
  };
}

class SettingsCubit extends HydratedCubit<SettingsState> {
  SettingsCubit({DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(SettingsState());

  final DateTime Function() _now;

  void setUnit(WeightUnit unit) => emit(state.copyWith(unit: unit));

  void setNotificationsEnabled(bool value) =>
      emit(state.copyWith(notificationsEnabled: value));

  void setAnalyticsEnabled(bool value) =>
      emit(state.copyWith(analyticsEnabled: value));

  void setPrefillSets(bool value) => emit(state.copyWith(prefillSets: value));

  void setNumberEntry(NumberEntry entry) =>
      emit(state.copyWith(numberEntry: entry));

  /// Makes [splitId] the current split. [previous], the split that was
  /// current until now, counts as just used, so it lists right below it.
  void setCurrentSplit(int? splitId, {int? previous}) => emit(
    state.copyWith(
      currentSplitId: splitId,
      splitsUsedAt: previous == null || previous == splitId
          ? null
          : {...state.splitsUsedAt, previous: _now()},
    ),
  );

  /// Drops a deleted split, and makes the current split follow the most
  /// recently trained one again when it was the deleted one.
  void forgetSplit(int splitId) => emit(
    state.copyWith(
      currentSplitId: state.currentSplitId == splitId
          ? null
          : state.currentSplitId,
      splitsUsedAt: {...state.splitsUsedAt}..remove(splitId),
    ),
  );

  void setDefaultRepMode(RepMode mode) =>
      emit(state.copyWith(defaultRepMode: mode));

  void setDefaultReps(int reps) {
    if (reps < 1) return;
    emit(state.copyWith(defaultReps: reps));
  }

  void setDefaultRepRange({required int min, required int max}) {
    if (min < 1 || max < min) return;
    emit(state.copyWith(defaultRepRangeMin: min, defaultRepRangeMax: max));
  }

  void setShowHeavyWeightWarning(bool value) =>
      emit(state.copyWith(showHeavyWeightWarning: value));

  void confirmHeavyWeight() => emit(state.copyWith(heavyWeightConfirmed: true));

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
