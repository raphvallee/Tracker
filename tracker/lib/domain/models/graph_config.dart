/// What a graph shows for its exercise. Saved by name: new values go last.
enum GraphMetric {
  /// Each session's best set, worked out to one rep.
  best1rm,

  /// The most weight on the bar each session, any reps.
  peakWeight,

  /// Weight × reps of every working set, per week or month.
  volume,

  /// The best estimated 1RM ever lifted: it only climbs on a new record.
  record1rm,
}

/// How far back the graphs look. One range is shared by every graph.
enum GraphTimeframe { all, last30Days, last90Days, lastYear }

/// A graph of one exercise. It names itself after the exercise and what it
/// shows, so there is nothing to type.
class GraphConfig {
  const GraphConfig({
    required this.exerciseId,
    this.metric = GraphMetric.best1rm,
  });

  final int exerciseId;
  final GraphMetric metric;

  GraphConfig copyWith({int? exerciseId, GraphMetric? metric}) => GraphConfig(
    exerciseId: exerciseId ?? this.exerciseId,
    metric: metric ?? this.metric,
  );

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'metric': metric.name,
  };

  @override
  bool operator ==(Object other) =>
      other is GraphConfig &&
      exerciseId == other.exerciseId &&
      metric == other.metric;

  @override
  int get hashCode => Object.hash(exerciseId, metric);

  // ignore: sort_constructors_first
  factory GraphConfig.fromJson(Map<String, dynamic> json) {
    // Graphs saved before every graph had its own exercise ("All
    // exercises") carry no id and are dropped by the caller.
    final exerciseId = json['exerciseId'];
    if (exerciseId is! num) {
      throw const FormatException('Graph exercise is required');
    }
    return GraphConfig(
      exerciseId: exerciseId.toInt(),
      metric:
          GraphMetric.values.asNameMap()[json['metric']] ?? GraphMetric.best1rm,
    );
  }
}
