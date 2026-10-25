import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/graph_config.dart';
import 'package:tracker/domain/services/analytics.dart';
import 'package:tracker/ui/core/ui/keyboard_inset.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/analytics/widgets/graph_exercise_picker_page.dart';
import 'package:tracker/utils/form_validators.dart';

/// Modal bottom-sheet editor for creating or editing a feed graph.
///
/// Built on `showModalBottomSheet` instead of `FDialog` on purpose: the
/// dialog's full-screen animated backdrop blur dropped the entrance to a
/// frame-by-frame crawl over the chart-heavy feed, and its autofocus only
/// fired after the route animation finished, so the keyboard lagged
/// visibly behind the popup. The sheet uses a plain dim barrier and slides up
/// with no blur. No field is autofocused so the keyboard does not pop up when
/// the sheet opens.
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
    builder: (sheetContext) {
      // The sheet lifts its bottom edge above the keyboard (padding outside
      // the scroll view below), so the keyboard can never cover its content
      // and fields inside must not use the app's keyboard-height reveal
      // overshoot - with the exercise picker open it would over-scroll the
      // search field. Give the fields the plain reveal gap instead.
      final theme = sheetContext.theme.copyWith(
        textFieldStyles: sheetContext.theme.textFieldStyles.apply([
          .all(
            .delta(
              scrollPadding: EdgeInsetsDelta.delta(bottom: kKeyboardRevealGap),
            ),
          ),
        ]),
      );
      return FTheme(
        data: theme,
        child: _GraphEditorSheet(initial: initial, exercises: exercises),
      );
    },
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
  late final TextEditingController _exerciseDisplay;
  late final FocusNode _titleFocus;
  late int? _exerciseId;
  late GraphMetric _metric;
  late GraphTimeframe _timeframe;

  /// Whether the user has manually edited the title. When false the title is
  /// either empty or auto-generated from the selected exercise, so picking a
  /// different exercise regenerates it to mirror the new choice.
  bool _titleEditedByUser = false;
  String? _titleError;

  /// Whether the exercise picker route is already being opened, used to guard
  /// against double-taps firing the push twice.
  bool _isPicking = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _title = TextEditingController(text: initial?.title ?? '');
    _titleFocus = FocusNode();
    _exerciseId = initial?.exerciseId;
    _metric = initial?.metric ?? GraphMetric.best1rm;
    _timeframe = initial?.timeframe ?? GraphTimeframe.all;
    _exerciseDisplay = TextEditingController(text: _exerciseValueLabel);
    // A persisted title is treated as a manual choice and preserved when the
    // exercise changes. A fresh (empty) title is auto-named from the exercise.
    _titleEditedByUser = initial != null && initial.title.isNotEmpty;
    // Clear the empty-title error once the title has actual text. The
    // controller also notifies on selection changes (e.g. when focusing the
    // field after a failed save), which must not dismiss the error.
    _title.addListener(() {
      if (_titleError != null && _title.text.trim().isNotEmpty) {
        setState(() => _titleError = null);
      }
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _exerciseDisplay.dispose();
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
    final error = requiredText(_title.text);
    if (error != null) {
      setState(() => _titleError = error);
      _titleFocus.requestFocus();
      return;
    }
    Navigator.of(context).pop(
      GraphConfig(
        title: _title.text.trim(),
        exerciseId: _exerciseId,
        metric: _metric,
        timeframe: _timeframe,
      ),
    );
  }

  /// Opens the full-screen exercise picker over the sheet. When the user picks
  /// an exercise (or "All exercises") the sheet is updated and the title is
  /// auto-named to mirror the choice unless the user customized it manually.
  Future<void> _pickExercise() async {
    if (_isPicking) return;
    _isPicking = true;
    FocusScope.of(context).unfocus();
    try {
      final pick = await pushTo<GraphExercisePick>(
        context,
        GraphExercisePickerPage(
          exercises: widget.exercises,
          selectedId: _exerciseId,
        ),
      );
      if (!mounted || pick == null) return;
      switch (pick.kind) {
        case PickKind.specific:
          setState(() {
            _exerciseId = pick.exercise!.id;
            _exerciseDisplay.text = pick.exercise!.title;
            if (!_titleEditedByUser || _title.text.trim().isEmpty) {
              _title.text = '${pick.exercise!.title} Progress';
            }
          });
          break;
        case PickKind.all:
          setState(() {
            _exerciseId = null;
            _exerciseDisplay.text = 'All exercises';
            if (!_titleEditedByUser || _title.text.trim().isEmpty) {
              _title.text = 'All exercises Progress';
            }
          });
          break;
        case PickKind.cancelled:
          break;
      }
    } finally {
      _isPicking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return SafeArea(
      // The sheet is hosted by the tab navigator, which already stops above
      // the shell's bottom navigation bar. Applying the bottom safe-area inset
      // here would add a second gap below the Save button.
      top: false,
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The sheet lifts its bottom edge above the keyboard by padding
          // OUTSIDE the scroll view. (It used to pad the scroll content
          // instead: the sheet is bottom-anchored and grows to fit its
          // content, so the growing keyboard padding stretched the sheet by
          // the keyboard's full height, pushing the card to the top of the
          // screen and leaving a large blank, scrollable strip under the
          // Save button.)
          //
          // This sheet is hosted by the tab navigator, which stops above the
          // shell's bottom navigation bar, so the sheet's container bottom
          // already sits above the screen bottom and only part of the sheet
          // would actually be covered by the keyboard: lift by the covered
          // part only (keyboard inset minus that bottom gap), never the full
          // inset, or the content loses height and clips.
          final inset = keyboardInsetOf(context);
          final obstructed =
              MediaQuery.sizeOf(context).height - constraints.maxHeight;
          final lift = (inset - obstructed).clamp(0.0, inset).toDouble();
          return Padding(
            padding: EdgeInsets.only(bottom: lift),
            child: SingleChildScrollView(
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
                      error: _titleError == null ? null : Text(_titleError!),
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
                    child: FButton(onPress: _save, child: const Text('Save')),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
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

  /// The exercise selector: a single read-only input row showing the chosen
  /// exercise (or "All exercises") with a chevron. Tapping *anywhere* on the
  /// field opens the full-screen picker instead of expanding inline, so the
  /// sheet never layout-shifts or forces a scroll inside its limited height.
  /// The "Exercise" caption comes from the field's own label (like the Title
  /// field above it), so no separate section heading is drawn - that only
  /// duplicated the word.
  Widget _exerciseSection(FThemeData theme) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Semantics(
      button: true,
      child: GestureDetector(
        // The field spans the whole row, and its internals are absorbed:
        // otherwise the read-only input's own focus/tap recognizer (and any
        // suffix button) wins the gesture arena, leaving only part of the row
        // clickable. With the child absorbed, every pixel of the row routes to
        // this single tap handler.
        behavior: HitTestBehavior.opaque,
        onTap: _pickExercise,
        child: AbsorbPointer(
          child: FTextField(
            control: FTextFieldControl.managed(controller: _exerciseDisplay),
            label: const Text('Exercise'),
            readOnly: true,
            suffixBuilder: (context, style, variants) => Icon(
              FLucideIcons.chevronRight,
              color: theme.colors.mutedForeground,
            ),
          ),
        ),
      ),
    ),
  );

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
