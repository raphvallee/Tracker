import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/graph_config.dart';
import 'package:tracker/domain/services/analytics.dart';
import 'package:tracker/ui/core/ui/keyboard_inset.dart';

/// Modal bottom-sheet editor for creating or editing a feed graph.
///
/// Built on `showModalBottomSheet` instead of `FDialog` on purpose: the
/// dialog's full-screen animated backdrop blur dropped the entrance to a
/// frame-by-frame crawl over the chart-heavy feed, and its autofocus only
/// fired after the route animation finished, so the keyboard lagged
/// visibly behind the popup. The sheet uses a plain dim barrier, slides up
/// with no blur, and, when editing, focuses the title field mid-animation so
/// the keyboard rises together with it.
abstract final class GraphEditor {
  /// Shows the editor, resolving with the saved [GraphConfig] or null when
  /// dismissed.
  static Future<GraphConfig?> show(
    BuildContext context, {
    GraphConfig? initial,
    required List<Exercise> exercises,
  }) => showModalBottomSheet<GraphConfig>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.theme.colors.background,
    // Keep a 5px gutter on each side: the narrower sheet is centered and
    // the dimmed barrier shows through, so the page stays a little visible.
    constraints: BoxConstraints(
      maxWidth: MediaQuery.sizeOf(context).width - 10,
    ),
    builder: (sheetContext) =>
        _GraphEditorSheet(initial: initial, exercises: exercises),
  );
}

class _GraphEditorSheet extends StatefulWidget {
  const _GraphEditorSheet({this.initial, required this.exercises});

  final GraphConfig? initial;
  final List<Exercise> exercises;

  @override
  State<_GraphEditorSheet> createState() => _GraphEditorSheetState();
}

class _GraphEditorSheetState extends State<_GraphEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _search;
  late final FocusNode _titleFocus;
  late int? _exerciseId;
  late GraphMetric _metric;
  late GraphTimeframe _timeframe;
  bool _pickingExercise = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _title = TextEditingController(text: initial?.title ?? '');
    _search = TextEditingController();
    _titleFocus = FocusNode();
    _exerciseId = initial?.exerciseId;
    _metric = initial?.metric ?? GraphMetric.best1rm;
    _timeframe = initial?.timeframe ?? GraphTimeframe.all;
    // Focus the title while the sheet is still animating in: modal routes
    // only deliver `autofocus` after the entrance completes, which visibly
    // delayed the keyboard. Only for editing: adding a graph should not
    // grab focus right away.
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _titleFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _search.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  String get _exerciseValueLabel => _exerciseId == null
      ? 'All exercises'
      : widget.exercises
                .where((exercise) => exercise.id == _exerciseId)
                .map((exercise) => exercise.title)
                .firstOrNull ??
            'Exercise';

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop(
      GraphConfig(
        title: title,
        exerciseId: _exerciseId,
        metric: _metric,
        timeframe: _timeframe,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        // The shell Scaffold opts out of resize-to-avoid-insets, so the
        // sheet has to clear the keyboard itself.
        padding: EdgeInsets.only(bottom: keyboardInsetOf(context)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(theme),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FTextField(
                control: FTextFieldControl.managed(controller: _title),
                focusNode: _titleFocus,
                label: const Text('Title'),
                hint: 'e.g. Squat progress',
              ),
            ),
            const SizedBox(height: 12),
            _exerciseSection(theme),
            const SizedBox(height: 12),
            _optionGroup(
              theme,
              label: 'Metric',
              options: [
                for (final metric in GraphMetric.values)
                  (
                    label: graphMetricLabel(metric),
                    selected: metric == _metric,
                    onPress: () => setState(() => _metric = metric),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _optionGroup(
              theme,
              label: 'Timeframe',
              options: [
                for (final timeframe in GraphTimeframe.values)
                  (
                    label: graphTimeframeLabel(timeframe),
                    selected: timeframe == _timeframe,
                    onPress: () => setState(() => _timeframe = timeframe),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _title,
                builder: (context, value, _) => FButton(
                  onPress: value.text.trim().isEmpty ? null : _save,
                  child: const Text('Save'),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _header(FThemeData theme) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
    child: Row(
      children: [
        Expanded(
          child: Text(
            widget.initial == null ? 'Add graph' : 'Edit graph',
            style: theme.typography.body.lg.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        FButton.icon(
          variant: .ghost,
          onPress: () => Navigator.of(context).pop(),
          child: const Icon(FLucideIcons.x),
        ),
      ],
    ),
  );

  Widget _exerciseSection(FThemeData theme) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Exercise',
          style: theme.typography.body.sm.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        FItem(
          // The value row is the only toggle: tap to expand, tap again to
          // collapse; the chevron flips to show which way it goes.
          onPress: () => setState(() {
            if (_pickingExercise) {
              _search.clear();
              _pickingExercise = false;
            } else {
              _pickingExercise = true;
              // Get the keyboard out of the way so the whole list shows.
              FocusScope.of(context).unfocus();
            }
          }),
          title: Text(_exerciseValueLabel),
          suffix: Icon(
            _pickingExercise
                ? FLucideIcons.chevronUp
                : FLucideIcons.chevronDown,
          ),
        ),
        if (_pickingExercise) ...[
          const SizedBox(height: 4),
          _exercisePicker(theme),
        ],
      ],
    ),
  );

  /// Inline, lazily-built exercise picker. Rendered in place instead of an
  /// overlay popover so it never triggers the popover's animated backdrop
  /// filter, and `ListView.builder` keeps only visible rows alive.
  Widget _exercisePicker(FThemeData theme) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FTextField(
        control: FTextFieldControl.managed(controller: _search),
        label: const Text('Search'),
        hint: 'Filter exercises',
      ),
      const SizedBox(height: 4),
      SizedBox(
        height: 260,
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _search,
          builder: (context, value, _) {
            final query = value.text.trim().toLowerCase();
            final matches = [
              for (final exercise in widget.exercises)
                if (exercise.title.toLowerCase().contains(query)) exercise,
            ];
            return ListView.builder(
              key: const ValueKey('exercise-options'),
              itemCount: 1 + matches.length,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return FItem(
                    title: const Text('All exercises'),
                    onPress: () => _pickExercise(null),
                  );
                }
                final exercise = matches[index - 1];
                return FItem(
                  title: Text(exercise.title),
                  onPress: () => _pickExercise(exercise.id),
                );
              },
            );
          },
        ),
      ),
    ],
  );

  void _pickExercise(int? exerciseId) {
    _search.clear();
    setState(() {
      _exerciseId = exerciseId;
      _pickingExercise = false;
    });
  }

  Widget _optionGroup(
    FThemeData theme, {
    required String label,
    required List<({String label, bool selected, VoidCallback onPress})>
    options,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.typography.body.sm.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              FButton(
                variant: option.selected ? .secondary : .outline,
                mainAxisSize: .min,
                onPress: option.onPress,
                child: Text(option.label),
              ),
          ],
        ),
      ],
    ),
  );
}
