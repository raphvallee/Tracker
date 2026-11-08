enum GraphMetric { best1rm, peakWeight, volume }

enum GraphTimeframe { all, last30Days, last90Days, lastYear }

class GraphConfig {
  const GraphConfig({
    required this.title,
    this.exerciseId,
    this.metric = GraphMetric.best1rm,
    this.timeframe = GraphTimeframe.all,
  });

  final String title;
  final int? exerciseId;
  final GraphMetric metric;
  final GraphTimeframe timeframe;

  GraphConfig copyWith({
    String? title,
    Object? exerciseId = _unset,
    GraphMetric? metric,
    GraphTimeframe? timeframe,
  }) => GraphConfig(
    title: title ?? this.title,
    exerciseId: identical(exerciseId, _unset)
        ? this.exerciseId
        : exerciseId as int?,
    metric: metric ?? this.metric,
    timeframe: timeframe ?? this.timeframe,
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'exerciseId': exerciseId,
    'metric': metric.name,
    'timeframe': timeframe.name,
  };

  @override
  bool operator ==(Object other) =>
      other is GraphConfig &&
      title == other.title &&
      exerciseId == other.exerciseId &&
      metric == other.metric &&
      timeframe == other.timeframe;

  @override
  int get hashCode => Object.hash(title, exerciseId, metric, timeframe);

  static const _unset = Object();

  // ignore: sort_constructors_first
  factory GraphConfig.fromJson(Map<String, dynamic> json) {
    final title = json['title'];
    if (title is! String || title.trim().isEmpty) {
      throw const FormatException('Graph title is required');
    }
    final exerciseId = json['exerciseId'];
    return GraphConfig(
      title: title,
      exerciseId: exerciseId is num ? exerciseId.toInt() : null,
      metric:
          GraphMetric.values.asNameMap()[json['metric']] ?? GraphMetric.best1rm,
      timeframe:
          GraphTimeframe.values.asNameMap()[json['timeframe']] ??
          GraphTimeframe.all,
    );
  }
}
