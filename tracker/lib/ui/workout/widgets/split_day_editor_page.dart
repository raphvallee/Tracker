import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/rep_mode.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/core/ui/keyboard_inset.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/core/ui/unsaved_changes_dialog.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/workout/widgets/exercise_picker_page.dart';
import 'package:tracker/utils/form_validators.dart';

/// Split day editor (Plan.md §1.3.1.1 / §1.3.1.1.1): configure a day's title,
/// description and ordered exercise list (add / remove / reorder). Every
/// exercise carries at least one planned set; each exercise's sets are edited
/// inline on this page - fixed reps or a min-max rep range per set, with new
/// sets pre-filled from the workout defaults in Settings. Pops the edited
/// [WorkoutSplitDay] so the parent split editor can store it.
class SplitDayEditorPage extends StatefulWidget {
  const SplitDayEditorPage({super.key, required this.day});

  final WorkoutSplitDay day;

  @override
  State<SplitDayEditorPage> createState() => _SplitDayEditorPageState();
}

class _SplitDayEditorPageState extends State<SplitDayEditorPage> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  List<ExerciseItem> _items = [];
  Map<int, String> _names = const {};
  bool _didLoad = false;
  String? _titleError;

  /// Snapshot of the day as seeded; compared against the live draft to
  /// detect unsaved changes when the user tries to leave without saving.
  WorkoutSplitDay? _initial;

  /// Cached dirty flag driving [PopScope.canPop]. Kept in sync through
  /// [_refreshPopGuard] instead of a full rebuild on every keystroke, so
  /// set-row validation errors (cleared in didUpdateWidget) survive typing.
  bool _dirty = false;

  SettingsState get _settings =>
      SettingsCubit.maybeOf(context)?.state ?? SettingsState();

  @override
  void initState() {
    super.initState();
    _title.text = widget.day.title;
    _description.text = widget.day.description;
    // Adding sets is mandatory: seed legacy items (saved before sets existed)
    // from their old targets, or from the configured defaults, so every
    // exercise always has at least one set. The set lists are copied so the
    // editor never mutates the caller's day object.
    _items = [for (final item in widget.day.exercises) _withSeededSets(item)];
    _initial = _snapshot();
    _dirty = false;
  }

  /// A normalized copy of the current draft, used as the dirty-check
  /// baseline. Normalization mirrors [_save] (trimmed texts, reindexed
  /// orders) so only content differences read as unsaved changes.
  WorkoutSplitDay _snapshot() => WorkoutSplitDay(
    title: _title.text.trim(),
    description: _description.text.trim(),
    exercises: [
      for (var i = 0; i < _items.length; i++)
        ExerciseItem(
          exerciseId: _items[i].exerciseId,
          order: i,
          sets: List.of(_items[i].sets),
        ),
    ],
  );

  /// True when the draft differs from what was seeded (see [_initial]):
  /// title, description, exercises, or their planned sets.
  bool get _hasUnsavedChanges => _dirty;

  /// Recomputes the dirty flag and rebuilds only when it flips, so per-
  /// keystroke rebuilds do not disturb the set rows' editing state.
  void _refreshPopGuard() {
    final initial = _initial;
    final dirty = initial != null && !splitDayPlanEquals(_snapshot(), initial);
    if (dirty != _dirty) {
      setState(() => _dirty = dirty);
    }
  }

  /// Returns a copy of [item] with its set list guaranteed non-empty. Items
  /// that already carry sets pass through with a copied list; legacy items
  /// synthesize `targetSets` fixed sets of `targetReps` when given, or sets
  /// from the configured default rep mode otherwise.
  ExerciseItem _withSeededSets(ExerciseItem item) {
    if (item.sets.isNotEmpty) {
      return ExerciseItem(
        exerciseId: item.exerciseId,
        order: item.order,
        targetSets: item.targetSets,
        targetReps: item.targetReps,
        restSeconds: item.restSeconds,
        sets: List.of(item.sets),
      );
    }
    final count = (item.targetSets != null && item.targetSets! > 0)
        ? item.targetSets!
        : 1;
    final legacyReps = (item.targetReps != null && item.targetReps! > 0)
        ? item.targetReps!
        : null;
    return ExerciseItem(
      exerciseId: item.exerciseId,
      order: item.order,
      targetSets: item.targetSets,
      targetReps: item.targetReps,
      restSeconds: item.restSeconds,
      sets: [
        for (var i = 0; i < count; i++)
          legacyReps == null
              ? _defaultSet(i)
              : PlannedSet(order: i, minReps: legacyReps),
      ],
    );
  }

  /// A set created from the workout defaults in Settings: fixed reps or a
  /// rep range, depending on the configured default rep mode.
  PlannedSet _defaultSet(int order) {
    final fixed = _settings.defaultRepMode == RepMode.fixed;
    return PlannedSet(
      order: order,
      minReps: fixed ? _settings.defaultReps : _settings.defaultRepRangeMin,
      maxReps: fixed ? null : _settings.defaultRepRangeMax,
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // RepositoryScope is an inherited widget, so read it here (after initState).
    // Guard so a dependency change doesn't re-run the async load.
    if (!_didLoad) {
      _didLoad = true;
      _loadNames();
    }
  }

  Future<void> _loadNames() async {
    final repo = RepositoryScope.maybeOf(context);
    final exercises = await repo?.exercises.getAll() ?? const [];
    if (!mounted) return;
    setState(() {
      _names = {for (final e in exercises) e.id: e.title};
    });
  }

  Future<void> _addExercise() async {
    final exercise = await pushTo(context, const ExercisePickerPage());
    if (exercise != null && mounted) {
      setState(() {
        // Mandatory sets: a new exercise starts with one set from the
        // configured default rep mode in Settings.
        _items.add(
          ExerciseItem(
            exerciseId: exercise.id,
            order: _items.length,
            sets: [_defaultSet(0)],
          ),
        );
      });
      _refreshPopGuard();
    }
  }

  void _addSet(int exerciseIndex) {
    setState(() {
      final sets = _items[exerciseIndex].sets;
      if (sets.isEmpty) {
        // No previous set: fall back to the configured default rep mode.
        sets.add(_defaultSet(0));
      } else {
        // Match the previous set's rep mode and values.
        final last = sets.last;
        sets.add(
          PlannedSet(
            order: sets.length,
            minReps: last.minReps,
            maxReps: last.maxReps,
          ),
        );
      }
    });
    _refreshPopGuard();
  }

  void _removeSet(int exerciseIndex, int setIndex) {
    // Mandatory sets: never remove an exercise's last remaining set.
    if (_items[exerciseIndex].sets.length <= 1) return;
    setState(() => _items[exerciseIndex].sets.removeAt(setIndex));
    _refreshPopGuard();
  }

  /// Commits an edited set into [_items] without a parent rebuild: the row
  /// owns its text fields, so rebuilding the list would be redundant (and
  /// could disturb focus while typing).
  void _onSetChanged(int exerciseIndex, int setIndex, PlannedSet set) {
    _items[exerciseIndex].sets[setIndex] = set;
    // The row owns its text fields, so only refresh the PopScope discard
    // guard; a full rebuild here would clear the row's inline errors.
    _refreshPopGuard();
  }

  /// Normalizes a degenerate range (max <= min) to a fixed set.
  PlannedSet _normalizedSet(PlannedSet set, int order) {
    final degenerate = set.maxReps != null && set.maxReps! <= set.minReps;
    return PlannedSet(
      order: order,
      minReps: set.minReps,
      maxReps: degenerate ? null : set.maxReps,
    );
  }

  void _save() {
    _titleError = requiredText(_title.text);
    if (_titleError != null) {
      setState(() {});
      return;
    }
    final day = WorkoutSplitDay(
      title: _title.text.trim(),
      description: _description.text.trim(),
      exercises: [
        for (var i = 0; i < _items.length; i++)
          ExerciseItem(
            exerciseId: _items[i].exerciseId,
            order: i,
            targetSets: _items[i].targetSets,
            targetReps: _items[i].targetReps,
            restSeconds: _items[i].restSeconds,
            sets: [
              for (var j = 0; j < _items[i].sets.length; j++)
                _normalizedSet(_items[i].sets[j], j),
            ],
          ),
      ],
    );
    Navigator.of(context).pop(day);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Guard back navigation (app-bar chevron and system back) so a day
      // with unsaved changes asks before being thrown away. Done pops the
      // edited day through _save, which is not intercepted.
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await confirmDiscardUnsavedChanges(context) && mounted) {
          navigator.pop();
        }
      },
      child: CustomScrollView(
        slivers: <Widget>[
          CustomAppBar(
            context,
            title: _title.text.isEmpty ? 'Edit Day' : _title.text,
            actionButton: (title: 'Done', onPressed: _save),
          ),
          SliverToBoxAdapter(
            child: Padding(
              // Bottom padding tracks the keyboard so the fields and the
              // planned-set editors can scroll above it (shell no longer
              // resizes for the keyboard).
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + keyboardInsetOf(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  FTextField(
                    control: FTextFieldControl.managed(
                      controller: _title,
                      onChange: (_) {
                        setState(() => _titleError = null);
                        _refreshPopGuard();
                      },
                    ),
                    label: const Text('Day name'),
                    error: _titleError == null ? null : Text(_titleError!),
                  ),
                  const SizedBox(height: 16),
                  FTextField(
                    control: FTextFieldControl.managed(
                      controller: _description,
                      // Refresh the PopScope discard guard on edits.
                      onChange: (_) => _refreshPopGuard(),
                    ),
                    label: const Text('Description (optional)'),
                    minLines: 1,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: <Widget>[
                      Text(
                        'Exercises',
                        style: context.theme.typography.body.md,
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: _addExercise,
                        icon: const Icon(FLucideIcons.plus, size: 18),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_items.isEmpty)
                    const Text('No exercises yet')
                  else
                    _buildReorderableList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReorderableList() {
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorderItem: _onReorder,
      children: [
        for (var i = 0; i < _items.length; i++)
          Padding(
            key: ValueKey('day-item-${_items[i].exerciseId}-$i'),
            padding: const EdgeInsets.only(bottom: 4),
            child: _buildExerciseBlock(i),
          ),
      ],
    );
  }

  /// One exercise: an orderable header row plus its planned sets, edited
  /// inline beneath it. Header, caption and set rows all use [_gridRow], so
  /// their columns line up vertically.
  Widget _buildExerciseBlock(int i) {
    final item = _items[i];
    final theme = context.theme;
    final captionStyle = theme.typography.body.xs.copyWith(
      color: theme.colors.mutedForeground,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _gridRow(
          leading: ReorderableDragStartListener(
            index: i,
            child: const Icon(FLucideIcons.gripHorizontal, size: 18),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              '${i + 1}. ${_names[item.exerciseId] ?? 'Exercise ${item.exerciseId}'}',
              style: theme.typography.body.md.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          icon1: _gridIconButton(
            icon: FLucideIcons.plus,
            tooltip: 'Add set',
            onPressed: () => _addSet(i),
          ),
          icon2: _gridIconButton(
            icon: FLucideIcons.trash2,
            tooltip: 'Remove exercise',
            onPressed: () {
              setState(() => _items.removeAt(i));
              _refreshPopGuard();
            },
          ),
        ),
        if (item.sets.isNotEmpty)
          _gridRow(
            leading: Text('Set', style: captionStyle),
            child: Text('Reps per set', style: captionStyle),
          ),
        for (var j = 0; j < item.sets.length; j++)
          _SetRow(
            key: ValueKey('day-$i-set-$j'),
            set: item.sets[j],
            setNumber: j + 1,
            defaultRangeMax: _settings.defaultRepRangeMax,
            canDelete: item.sets.length > 1,
            onChanged: (set) => _onSetChanged(i, j, set),
            onDelete: () => _removeSet(i, j),
          ),
      ],
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      // onReorderItem already accounts for the removed item at oldIndex.
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
    _refreshPopGuard();
  }
}

/// Shared column grid for the split day editor: the exercise header, the
/// sets caption and every set row use the same leading column and two icon
/// columns, so all columns line up vertically. The page's 16 margin is the
/// grid's outer edge (rows add none of their own), which puts the right
/// icon column flush with the Add-exercise button.
const _gridLeading = 44.0;

/// Width of one right-aligned icon cell, and the gap between the two cells.
/// Tighter than a full touch square so the rep fields gain width; the cells
/// right-align their glyphs, so every row's icons - and both trash glyphs -
/// line up with the Add-exercise button's right edge on the content margin.
const _gridIcon = 28.0;
const _gridIconGap = 6.0;

/// Builds one row of the grid: a fixed-width leading cell (grip / set label),
/// the stretchable content, and up to two fixed-width icon cells whose
/// glyphs are right-aligned. No horizontal padding of its own: the enclosing
/// page already pads 16, so the last icon's right edge lands exactly on the
/// same margin as the Add-exercise button.
Widget _gridRow({
  required Widget leading,
  required Widget child,
  Widget? icon1,
  Widget? icon2,
}) {
  return Row(
    children: <Widget>[
      SizedBox(
        width: _gridLeading,
        child: Center(child: leading),
      ),
      Expanded(child: child),
      if (icon1 != null) ...[
        SizedBox(
          width: _gridIcon,
          child: Align(alignment: Alignment.centerRight, child: icon1),
        ),
        const SizedBox(width: _gridIconGap),
      ],
      if (icon2 != null)
        SizedBox(
          width: _gridIcon,
          child: Align(alignment: Alignment.centerRight, child: icon2),
        ),
    ],
  );
}

/// A compact icon button for one of the grid's icon cells.
Widget _gridIconButton({
  required IconData icon,
  required String tooltip,
  VoidCallback? onPressed,
}) {
  return IconButton(
    padding: EdgeInsets.zero,
    iconSize: 18,
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon),
  );
}

/// One planned set, edited inline: fixed reps, or a min-max rep range after
/// toggling. Text changes commit straight into the editor's draft data;
/// invalid input shows an error and keeps the last valid value.
class _SetRow extends StatefulWidget {
  const _SetRow({
    super.key,
    required this.set,
    required this.setNumber,
    required this.defaultRangeMax,
    required this.canDelete,
    required this.onChanged,
    required this.onDelete,
  });

  final PlannedSet set;

  /// 1-based position used for the row label (tracks list positions, so it
  /// stays correct after deletions even before the next save reindexes).
  final int setNumber;

  /// Settings default used to pre-fill the max when switching to a range.
  final int defaultRangeMax;

  /// False disables removal (the exercise's last mandatory set).
  final bool canDelete;
  final ValueChanged<PlannedSet> onChanged;
  final VoidCallback onDelete;

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late final TextEditingController _min;
  late final TextEditingController _max;
  late bool _isRange;
  String? _minError;
  String? _maxError;

  @override
  void initState() {
    super.initState();
    _isRange = widget.set.isRange;
    _min = TextEditingController(text: '${widget.set.minReps}');
    _max = TextEditingController(text: widget.set.maxReps?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant _SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rows are keyed by position, so after an add/remove the row may now
    // represent a different set: re-sync the fields to the new value.
    if (_min.text != '${widget.set.minReps}') {
      _min.text = '${widget.set.minReps}';
    }
    final maxText = widget.set.maxReps?.toString() ?? '';
    if (_max.text != maxText) {
      _max.text = maxText;
    }
    if (_isRange != widget.set.isRange) {
      _isRange = widget.set.isRange;
    }
    _minError = null;
    _maxError = null;
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  /// Validates the current fields and commits the set when valid. Empty
  /// fields are tolerated while typing (no commit, no error).
  void _commit() {
    final minText = _min.text.trim();
    final maxText = _max.text.trim();
    final min = int.tryParse(minText);
    final max = _isRange ? int.tryParse(maxText) : null;
    String? minError;
    String? maxError;
    if (minText.isNotEmpty && (min == null || min < 1)) {
      minError = 'Must be at least 1';
    }
    if (_isRange && maxText.isNotEmpty && (max == null || max < 1)) {
      maxError = 'Must be at least 1';
    }
    if (min != null && max != null && max < min) {
      maxError = 'Must be at least the min';
    }
    setState(() {
      _minError = minError;
      _maxError = maxError;
    });
    if (min == null || minError != null) return;
    if (_isRange && (max == null || maxError != null)) return;
    widget.onChanged(
      PlannedSet(
        order: widget.set.order,
        minReps: min,
        maxReps: _isRange ? max : null,
      ),
    );
  }

  /// Switches between fixed reps and a rep range, pre-filling the max from
  /// the configured default (raised above the min when necessary).
  void _toggleMode() {
    setState(() {
      _isRange = !_isRange;
      _minError = null;
      _maxError = null;
    });
    final min = int.tryParse(_min.text.trim()) ?? widget.set.minReps;
    if (_isRange) {
      var max = widget.defaultRangeMax;
      if (max <= min) max = min + 2;
      _max.text = max.toString();
      widget.onChanged(
        PlannedSet(order: widget.set.order, minReps: min, maxReps: max),
      );
    } else {
      widget.onChanged(
        PlannedSet(order: widget.set.order, minReps: min, maxReps: null),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    Widget field(TextEditingController controller, String? error) => Expanded(
      child: FTextField(
        control: FTextFieldControl.managed(
          controller: controller,
          onChange: (_) => _commit(),
        ),
        keyboardType: TextInputType.number,
        error: error == null ? null : Text(error),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: _gridRow(
        leading: Text(
          'Set ${widget.setNumber}',
          style: theme.typography.body.sm.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
        child: Row(
          children: <Widget>[
            field(_min, _minError),
            if (_isRange) ...[
              const SizedBox(width: 6),
              Text('-', style: theme.typography.body.sm),
              const SizedBox(width: 6),
              field(_max, _maxError),
            ],
          ],
        ),
        icon1: _gridIconButton(
          icon: _isRange ? FLucideIcons.hash : FLucideIcons.moveHorizontal,
          tooltip: _isRange ? 'Use fixed reps' : 'Use rep range',
          onPressed: _toggleMode,
        ),
        icon2: _gridIconButton(
          icon: FLucideIcons.trash2,
          tooltip: 'Remove set',
          onPressed: widget.canDelete ? widget.onDelete : null,
        ),
      ),
    );
  }
}
