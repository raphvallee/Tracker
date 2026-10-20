import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/domain/models/workout_split_templates.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/core/ui/keyboard_inset.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/core/ui/unsaved_changes_dialog.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';

import 'split_day_editor_page.dart';

/// Split CRUD editor (Plan.md §1.3.1). Handles both creating a new split and
/// editing an existing one ([split] null → create). Configures the split's
/// title/description and its ordered list of days; each day opens
/// [SplitDayEditorPage].
class SplitEditorPage extends StatefulWidget {
  const SplitEditorPage({super.key, this.split});

  /// The split being edited, or null to create a new one.
  final WorkoutSplit? split;

  @override
  State<SplitEditorPage> createState() => _SplitEditorPageState();
}

class _SplitEditorPageState extends State<SplitEditorPage> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  List<WorkoutSplitDay> _days = [];
  bool _saving = false;

  /// Snapshot of the split as loaded; compared against the live draft to
  /// detect unsaved changes when the user tries to leave without saving.
  /// For a new split this is the pristine empty draft.
  WorkoutSplit? _initial;

  bool get _isNew => widget.split == null;

  String? get _titleError =>
      _title.text.trim().isEmpty ? 'Cannot be empty' : null;

  /// True when the draft differs from what was loaded (see [_initial]):
  /// title, description, days, or their exercise plans.
  bool get _hasUnsavedChanges {
    final initial = _initial;
    if (initial == null) return false;
    if (initial.title != _title.text.trim()) return true;
    if (initial.description != _description.text.trim()) return true;
    final days = [
      for (var i = 0; i < _days.length; i++) _dayWithOrder(_days[i], i),
    ];
    if (days.length != initial.splitDays.length) return true;
    for (var i = 0; i < days.length; i++) {
      if (!splitDayPlanEquals(days[i], initial.splitDays[i])) return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    final s = widget.split;
    if (s != null) {
      _title.text = s.title;
      _description.text = s.description;
      _days = [
        for (final d in s.splitDays)
          WorkoutSplitDay(
            title: d.title,
            description: d.description,
            exercises: List.of(d.exercises),
            order: d.order,
          ),
      ];
    }
    _initial = _snapshot();
  }

  /// A normalized copy of the current draft, used as the dirty-check
  /// baseline. Normalization mirrors [_save] (trimmed texts, reindexed
  /// orders) so only content differences read as unsaved changes.
  WorkoutSplit _snapshot() => WorkoutSplit(
    title: _title.text.trim(),
    description: _description.text.trim(),
    splitDays: [
      for (var i = 0; i < _days.length; i++) _dayWithOrder(_days[i], i),
    ],
  );

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _openDayEditor(int index) async {
    final edited = await pushTo<WorkoutSplitDay>(
      context,
      SplitDayEditorPage(day: _days[index]),
    );
    if (edited != null && mounted) {
      setState(() => _days[index] = edited);
    }
  }

  Future<void> _addDay() async {
    final day = WorkoutSplitDay(
      title: 'Day ${_days.length + 1}',
      order: _days.length,
    );
    final edited = await pushTo<WorkoutSplitDay>(
      context,
      SplitDayEditorPage(day: day),
    );
    if (edited != null && mounted) {
      setState(() => _days = [..._days, _dayWithOrder(edited, _days.length)]);
    }
  }

  WorkoutSplitDay _dayWithOrder(WorkoutSplitDay day, int order) =>
      WorkoutSplitDay(
        title: day.title,
        description: day.description,
        exercises: List.of(day.exercises),
        order: order,
      );

  Future<void> _chooseTemplate() async {
    final template = await showFSheet<WorkoutSplitTemplate>(
      context: context,
      side: .btt,
      // showFSheet paints no surface of its own (see gym_picker.dart), so the
      // sheet paints an opaque themed background with rounded top corners.
      builder: (context) {
        final radius = context.theme.style.borderRadius.lg.topLeft.x;
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: context.theme.colors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
          ),
          padding: const EdgeInsets.only(top: 8),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final template in workoutSplitTemplates)
                FItem(
                  title: Text(template.title),
                  subtitle: Text('${template.days.length} days'),
                  onPress: () => Navigator.of(context).pop(template),
                ),
            ],
          ),
        );
      },
    );
    if (template != null && mounted) {
      setState(() {
        _title.text = template.title;
        _days = template.createDays();
      });
    }
  }

  Future<void> _deleteSplit() async {
    final split = widget.split;
    final repo = RepositoryScope.maybeOf(context);
    if (split == null || repo == null) return;
    final confirmed = await showFDialog<bool>(
      context: context,
      builder: (dialogContext, _, _) => FDialog(
        builder: (context, style) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Delete split?', style: style.titleTextStyle),
            const SizedBox(height: 8),
            Text('Remove "${split.title}"?', style: style.bodyTextStyle),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                FButton(
                  variant: .outline,
                  onPress: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FButton(
                  onPress: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && mounted) {
      await repo.splits.delete(split.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _save() async {
    if (_titleError != null) {
      setState(() {});
      return;
    }

    setState(() => _saving = true);
    final repo = RepositoryScope.maybeOf(context);

    final split = WorkoutSplit(
      title: _title.text.trim(),
      description: _description.text.trim(),
      splitDays: [
        for (var i = 0; i < _days.length; i++) _dayWithOrder(_days[i], i),
      ],
      order: widget.split?.order ?? -1,
    );
    if (widget.split != null) {
      split.id = widget.split!.id;
      split.order = widget.split!.order;
    } else if (repo != null) {
      var nextOrder = 0;
      final all = await repo.splits.getAll();
      if (all.isNotEmpty) {
        nextOrder = all.map((s) => s.order).reduce((a, b) => a > b ? a : b) + 1;
      }
      split.order = nextOrder;
    }

    if (repo != null) {
      await repo.splits.put(split);
    }
    if (!mounted) return;
    Navigator.of(context).pop(split);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Guard back navigation (app-bar chevron and system back) so an edit
      // split with unsaved changes asks before being thrown away. Save pops
      // with a result through _save, which is not intercepted.
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
            title: _isNew ? 'New Split' : 'Edit Split',
            actionButton: _saving ? null : (title: 'Save', onPressed: _save),
          ),
          SliverToBoxAdapter(
            child: Padding(
              // Bottom padding tracks the keyboard so the fields and the
              // trailing "Add day" action scroll above it (shell no longer
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
                      onChange: (_) => setState(() {}),
                    ),
                    label: const Text('Split name'),
                    error: _titleError == null ? null : Text(_titleError!),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _chooseTemplate,
                    icon: const Icon(FLucideIcons.sparkles),
                    label: const Text('Use a template'),
                  ),
                  const SizedBox(height: 16),
                  FTextField(
                    control: FTextFieldControl.managed(
                      controller: _description,
                      // Rebuild so the PopScope discard guard tracks edits.
                      onChange: (_) => setState(() {}),
                    ),
                    label: const Text('Description (optional)'),
                    minLines: 1,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                  ),
                  const SizedBox(height: 24),
                  Text('Days', style: context.theme.typography.body.md),
                  const SizedBox(height: 8),
                  if (_days.isEmpty)
                    const Text('No days yet - add one below.')
                  else
                    for (var i = 0; i < _days.length; i++)
                      FItem(
                        title: Text(_days[i].title),
                        subtitle: Text(
                          plural('exercise', _days[i].exercises.length),
                        ),
                        suffix: IconButton(
                          icon: const Icon(FLucideIcons.trash2),
                          tooltip: 'Remove day',
                          onPressed: () => setState(() => _days.removeAt(i)),
                        ),
                        onPress: () => _openDayEditor(i),
                      ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _addDay,
                    icon: const Icon(FLucideIcons.plus),
                    label: const Text('Add day'),
                  ),
                  const SizedBox(height: 16),
                  if (!_isNew)
                    FButton(
                      onPress: _deleteSplit,
                      child: const Text('Delete split'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
