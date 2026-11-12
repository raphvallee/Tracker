import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/graph_config.dart';
import 'package:tracker/ui/analytics/widgets/graph_exercise_picker_page.dart';
import 'package:tracker/ui/analytics/widgets/graph_readout.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/core/ui/edit_sheet.dart';
import 'package:tracker/ui/core/ui/item_card.dart';

/// The sheet that adds or edits a graph: which exercise, and what to
/// measure. The graph names itself from both, and the range lives on the
/// graphs, so there is nothing else to fill in.
abstract final class GraphEditor {
  static Future<GraphConfig?> show(
    BuildContext context, {
    GraphConfig? initial,
    required List<Exercise> exercises,
  }) => showEditSheet<GraphConfig>(
    context,
    builder: (_) => _GraphSheet(initial: initial, exercises: exercises),
  );
}

class _GraphSheet extends StatefulWidget {
  const _GraphSheet({this.initial, required this.exercises});

  final GraphConfig? initial;
  final List<Exercise> exercises;

  @override
  State<_GraphSheet> createState() => _GraphSheetState();
}

class _GraphSheetState extends State<_GraphSheet> {
  late Exercise? _exercise = _exerciseOf(widget.initial?.exerciseId);
  late GraphMetric _metric = widget.initial?.metric ?? GraphMetric.best1rm;
  bool _missingExercise = false;
  bool _picking = false;

  Exercise? _exerciseOf(int? id) {
    for (final exercise in widget.exercises) {
      if (exercise.id == id) return exercise;
    }
    return null;
  }

  Future<void> _pickExercise() async {
    if (_picking) return;
    _picking = true;
    try {
      final picked = await pushTo<Exercise>(
        context,
        GraphExercisePickerPage(
          exercises: widget.exercises,
          selectedId: _exercise?.id,
        ),
      );
      if (!mounted || picked == null) return;
      setState(() {
        _exercise = picked;
        _missingExercise = false;
      });
    } finally {
      _picking = false;
    }
  }

  void _save() {
    final exercise = _exercise;
    if (exercise == null) {
      setState(() => _missingExercise = true);
      return;
    }
    Navigator.of(context)
        .pop(GraphConfig(exerciseId: exercise.id, metric: _metric));
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final adding = widget.initial == null;
    return EditSheet(
      title: adding ? 'Add graph' : 'Edit graph',
      actionLabel: adding ? 'Add graph' : 'Save',
      onAction: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ItemCard(
            children: <FItemMixin>[
              FItem(
                title: const Text('Exercise'),
                details: Text(
                  _exercise?.title ?? 'Pick one',
                  style: _exercise == null
                      ? TextStyle(color: theme.colors.mutedForeground)
                      : null,
                ),
                suffix: const Icon(FLucideIcons.chevronRight),
                onPress: _pickExercise,
              ),
            ],
          ),
          if (_missingExercise)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: Text(
                'Pick the exercise to graph',
                style: theme.typography.body.xs.copyWith(
                  color: theme.colors.error,
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Measure',
            style: theme.typography.body.sm.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ItemCard(
            divider: .full,
            children: <FItemMixin>[
              for (final metric in graphMetrics)
                FItem(
                  selected: metric == _metric,
                  semanticsInMutuallyExclusiveGroup: true,
                  title: Text(
                    graphMetricLabel(metric),
                    style: metric == _metric
                        ? const TextStyle(fontWeight: FontWeight.w600)
                        : null,
                  ),
                  subtitle: Text(
                    graphMetricDescription(metric),
                    softWrap: true,
                    overflow: TextOverflow.visible,
                    style: const TextStyle(height: 1.35),
                  ),
                  suffix: metric == _metric
                      ? const Icon(FLucideIcons.check)
                      : const SizedBox(width: 16),
                  onPress: () => setState(() => _metric = metric),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
