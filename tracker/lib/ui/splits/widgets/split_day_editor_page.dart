import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/split_draft.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/domain/services/split_diff.dart';
import 'package:tracker/ui/core/themes/accents.dart';
import 'package:tracker/ui/core/ui/animated_reveal.dart';
import 'package:tracker/ui/core/ui/app_dialog.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/core/ui/icon_button.dart';
import 'package:tracker/ui/core/ui/keyboard_inset.dart';
import 'package:tracker/ui/core/ui/max_width.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/ui/splits/view_models/split_drafts_cubit.dart';
import 'package:tracker/ui/workout/widgets/exercise_picker_page.dart';
import 'package:tracker/ui/workout/widgets/start_workout.dart';

import 'draft_marks.dart';
import 'review_changes_sheet.dart';
import 'set_target_sheet.dart';

/// One day of a split: its name, its exercises in order and each planned
/// set's rep target. Edits land in the split's draft at once.
class SplitDayEditorPage extends StatefulWidget {
  const SplitDayEditorPage({
    super.key,
    required this.splitId,
    required this.dayIndex,
  });

  final int splitId;

  /// Position of the day in the split's draft.
  final int dayIndex;

  @override
  State<SplitDayEditorPage> createState() => _SplitDayEditorPageState();
}

class _SplitDayEditorPageState extends State<SplitDayEditorPage> {
  final List<StreamSubscription<Object?>> _subscriptions = [];
  WorkoutSplit? _saved;
  Map<int, String> _names = const {};
  final _title = TextEditingController();
  final _description = TextEditingController();
  bool _titleFocused = false;
  bool _descriptionFocused = false;
  bool _didLoad = false;
  bool _closing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    final repo = RepositoryScope.maybeOf(context);
    if (repo == null) return;
    _subscriptions
      ..add(
        repo.splits.watchAll().listen((splits) {
          WorkoutSplit? saved;
          for (final split in splits) {
            if (split.id == widget.splitId) saved = split;
          }
          if (saved == null) {
            _close();
            return;
          }
          final first = _saved == null;
          setState(() => _saved = saved);
          if (first) _syncFields();
        }),
      )
      ..add(
        repo.exercises.watchAll().listen(
          (exercises) => setState(
            () => _names = {
              for (final exercise in exercises) exercise.id: exercise.title,
            },
          ),
        ),
      );
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  SplitDraft? get _draft {
    final saved = _saved;
    if (saved == null) return null;
    return context.read<SplitDraftsCubit>().draftOf(
      saved,
      fallback: defaultSetTargetOf(context),
    );
  }

  /// Shows the draft's name and description, unless they are being typed.
  void _syncFields() {
    final draft = _draft;
    if (draft == null || widget.dayIndex >= draft.days.length) return;
    final day = draft.days[widget.dayIndex];
    if (!_titleFocused && _title.text != day.title) _title.text = day.title;
    if (!_descriptionFocused && _description.text != day.description) {
      _description.text = day.description;
    }
  }

  void _edit(SplitDraft Function(SplitDraft draft) change) {
    final saved = _saved;
    if (saved == null) return;
    context.read<SplitDraftsCubit>().edit(
      saved,
      change,
      fallback: defaultSetTargetOf(context),
    );
  }

  void _editDay(DayDraft Function(DayDraft day) change) =>
      _edit((draft) => draft.updateDay(widget.dayIndex, change));

  String _nameOf(int id) => _names[id] ?? 'Exercise $id';

  Future<void> _addExercise() async {
    final exercise = await pushTo<Exercise>(
      context,
      const ExercisePickerPage(),
    );
    if (exercise == null || !mounted) return;
    final fallback = defaultSetTargetOf(context);
    _editDay((day) => day.addExercise(exercise.id, [fallback]));
  }

  Future<void> _editSet(DayDraft day, int exercise, int set) async {
    final item = day.exercises[exercise];
    final saved = _savedTarget(day, exercise, set);
    final result = await showSetTargetSheet(
      context,
      title: '${_nameOf(item.exerciseId)}, set ${set + 1}',
      subtitle: saved == null
          ? '${day.title}. A new set.'
          : '${day.title}. Saved as ${saved.description}.',
      target: item.sets[set],
      setCount: item.sets.length,
    );
    if (result == null || !mounted) return;
    _editDay(
      (day) => day.updateExercise(exercise, (item) {
        if (result.delete) return item.removeSet(set);
        final target = result.target!;
        return result.applyToAll
            ? item.withAllSets(target)
            : item.withSet(set, target);
      }),
    );
  }

  /// The target [set] had in the saved split, when it was there.
  SetTarget? _savedTarget(DayDraft day, int exercise, int set) {
    final saved = _saved;
    final dayOrigin = day.origin;
    final origin = day.exercises[exercise].origin;
    if (saved == null || dayOrigin == null || origin == null) return null;
    final base = context.read<SplitDraftsCubit>().baseOf(
      saved,
      fallback: defaultSetTargetOf(context),
    );
    if (dayOrigin >= base.days.length) return null;
    final sets = base.days[dayOrigin].exercises[origin].sets;
    return set < sets.length ? sets[set] : null;
  }

  Future<void> _deleteDay(DayDraft day) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete ${day.title.isEmpty ? 'this day' : day.title}?',
      message:
          'It leaves the split when you save your changes, and can be '
          'restored until then.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    _closing = true;
    _edit((draft) => draft.removeDay(widget.dayIndex));
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final saved = _saved;
    if (saved == null) {
      return CustomScrollView(
        slivers: <Widget>[CustomAppBar(context, title: 'Day')],
      );
    }
    return BlocConsumer<SplitDraftsCubit, SplitDraftsState>(
      listener: (context, _) => _syncFields(),
      builder: (context, state) {
        final drafts = context.read<SplitDraftsCubit>();
        final fallback = defaultSetTargetOf(context);
        final draft = drafts.draftOf(saved, fallback: fallback);
        if (widget.dayIndex >= draft.days.length) {
          _close();
          return const SizedBox.shrink();
        }
        final base = drafts.baseOf(saved, fallback: fallback);
        final diff = diffSplit(base, draft, nameOf: _nameOf);
        final day = draft.days[widget.dayIndex];
        return Stack(
          children: <Widget>[
            CustomScrollView(
              slivers: <Widget>[
                CustomAppBar(
                  context,
                  title: day.title.isEmpty ? 'Untitled day' : day.title,
                  trailing: _menu(context, day),
                ),
                SliverToBoxAdapter(
                  child: MaxWidth(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        4,
                        16,
                        keyboardClearanceOf(context),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _content(context, day, base, diff),
                          // Room to scroll clear of the save bar, opening
                          // and closing with it.
                          AnimatedReveal(
                            fade: false,
                            child: diff.isEmpty
                                ? null
                                : const SizedBox(height: 76),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Slides up from the bottom edge while there are unsaved
            // changes, and back down once they are saved or discarded.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedReveal(
                fade: false,
                child: diff.isEmpty
                    ? null
                    : _SaveBar(
                        count: diff.count,
                        onReview: () => showReviewChangesSheet(
                          context,
                          split: saved,
                          names: _names,
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _menu(BuildContext context, DayDraft day) {
    final destructive = context.theme.colors.destructive;
    return FPopoverMenu.tiles(
      menuAnchor: .topRight,
      childAnchor: .bottomRight,
      menuBuilder: (menuContext, controller, _) => [
        .group(
          children: [
            .tile(
              prefix: Icon(FLucideIcons.trash2, color: destructive),
              title: Text('Delete day', style: TextStyle(color: destructive)),
              onPress: () {
                controller.hide();
                _deleteDay(day);
              },
            ),
          ],
        ),
      ],
      builder: (_, controller, _) => AppIconButton(
        icon: FLucideIcons.ellipsis,
        tooltip: 'Day options',
        onPress: controller.toggle,
      ),
    );
  }

  Widget _content(
    BuildContext context,
    DayDraft day,
    SplitDraft base,
    SplitDiff diff,
  ) {
    final theme = context.theme;
    final baseDay = day.origin != null && day.origin! < base.days.length
        ? base.days[day.origin!]
        : null;
    final removed = diff.removedExercises[widget.dayIndex] ?? const <int>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (focused) => _titleFocused = focused,
          child: FTextField(
            control: FTextFieldControl.managed(
              controller: _title,
              onChange: (value) =>
                  _editDay((day) => day.copyWith(title: value.text)),
            ),
            label: const Text('Day name'),
            error: day.title.trim().isEmpty
                ? const Text('Name the day to save it')
                : null,
          ),
        ),
        const SizedBox(height: 12),
        Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (focused) => _descriptionFocused = focused,
          child: FTextField(
            control: FTextFieldControl.managed(
              controller: _description,
              onChange: (value) =>
                  _editDay((day) => day.copyWith(description: value.text)),
            ),
            label: const Text('Description (optional)'),
            minLines: 1,
            maxLines: null,
            keyboardType: TextInputType.multiline,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Exercises',
                style: theme.typography.body.sm.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            FButton(
              variant: .outline,
              size: .sm,
              mainAxisSize: .min,
              onPress: _addExercise,
              prefix: const Icon(FLucideIcons.plus),
              child: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (day.exercises.isEmpty && removed.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No exercises yet. Add the ones you do on this day.',
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          ),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem: (oldIndex, newIndex) =>
              _editDay((day) => day.reorderExercise(oldIndex, newIndex)),
          children: <Widget>[
            for (final (k, exercise) in day.exercises.indexed)
              Padding(
                key: ValueKey(
                  'day-exercise-${exercise.origin ?? 'new'}-'
                  '${exercise.exerciseId}-$k',
                ),
                padding: const EdgeInsets.only(bottom: 8),
                child: _ExerciseBlock(
                  index: k,
                  name: _nameOf(exercise.exerciseId),
                  exercise: exercise,
                  isNew: diff.isNewExercise(widget.dayIndex, k),
                  isEdited: diff.isChangedExercise(widget.dayIndex, k),
                  changedSet: (set) =>
                      diff.isChangedSet(widget.dayIndex, k, set),
                  onSet: (set) => _editSet(day, k, set),
                  onAddSet: () => _editDay(
                    (day) => day.updateExercise(
                      k,
                      (item) => item.addSet(defaultSetTargetOf(context)),
                    ),
                  ),
                  onRemove: () => _editDay((day) => day.removeExercise(k)),
                ),
              ),
          ],
        ),
        if (baseDay != null)
          for (final origin in removed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RemovedRow(
                boxed: true,
                label: _nameOf(baseDay.exercises[origin].exerciseId),
                onRestore: () =>
                    _editDay((day) => day.restoreExercise(baseDay, origin)),
              ),
            ),
      ],
    );
  }
}

class _ExerciseBlock extends StatelessWidget {
  const _ExerciseBlock({
    required this.index,
    required this.name,
    required this.exercise,
    required this.isNew,
    required this.isEdited,
    required this.changedSet,
    required this.onSet,
    required this.onAddSet,
    required this.onRemove,
  });

  final int index;
  final String name;
  final ExerciseDraft exercise;
  final bool isNew;
  final bool isEdited;
  final bool Function(int set) changedSet;
  final void Function(int set) onSet;
  final VoidCallback onAddSet;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final accents = TrackerAccents.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 4, 4, 10),
      decoration: BoxDecoration(
        color: theme.colors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNew || isEdited ? accents.draftLine : theme.colors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              ReorderableDragStartListener(
                index: index,
                child: SizedBox(
                  width: 36,
                  height: 40,
                  child: Icon(
                    FLucideIcons.gripVertical,
                    size: 18,
                    color: theme.colors.mutedForeground,
                  ),
                ),
              ),
              SizedBox(
                width: 20,
                child: Text(
                  '${index + 1}',
                  style: theme.typography.body.xs.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
              ),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: <Widget>[
                    Text(
                      name,
                      style: theme.typography.body.sm.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isNew)
                      const DraftTag('New')
                    else if (isEdited)
                      const DraftTag('Edited'),
                  ],
                ),
              ),
              FPopoverMenu.tiles(
                menuAnchor: .topRight,
                childAnchor: .bottomRight,
                menuBuilder: (menuContext, controller, _) => [
                  .group(
                    children: [
                      .tile(
                        prefix: Icon(
                          FLucideIcons.trash2,
                          color: theme.colors.destructive,
                        ),
                        title: Text(
                          'Remove exercise',
                          style: TextStyle(color: theme.colors.destructive),
                        ),
                        onPress: () {
                          controller.hide();
                          onRemove();
                        },
                      ),
                    ],
                  ),
                ],
                builder: (_, controller, _) => AppIconButton(
                  icon: FLucideIcons.ellipsis,
                  tooltip: 'Exercise options',
                  onPress: controller.toggle,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 36, top: 2),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final (j, set) in exercise.sets.indexed)
                  _SetChip(
                    target: set,
                    setNumber: j + 1,
                    changed: changedSet(j),
                    onPress: () => onSet(j),
                  ),
                _AddSetChip(onPress: onAddSet),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetChip extends StatelessWidget {
  const _SetChip({
    required this.target,
    required this.setNumber,
    required this.changed,
    required this.onPress,
  });

  final SetTarget target;
  final int setNumber;
  final bool changed;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final accents = TrackerAccents.of(context);
    return FTappable(
      semanticsLabel: 'Set $setNumber, ${target.description}',
      onPress: onPress,
      child: Container(
        constraints: const BoxConstraints(minWidth: 48),
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: changed ? accents.draftSoft : theme.colors.muted,
          borderRadius: BorderRadius.circular(8),
          border: changed ? Border.all(color: accents.draft, width: 1.5) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              target.label,
              style: theme.typography.body.xs.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.1,
                color: changed ? accents.draftInk : theme.colors.foreground,
              ),
            ),
            Text(
              target.unit,
              style: theme.typography.body.xs3.copyWith(
                height: 1.1,
                color: changed
                    ? accents.draftInk
                    : theme.colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddSetChip extends StatelessWidget {
  const _AddSetChip({required this.onPress});

  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return FTappable(
      semanticsLabel: 'Add set',
      onPress: onPress,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colors.border),
        ),
        child: Icon(
          FLucideIcons.plus,
          size: 16,
          color: theme.colors.mutedForeground,
        ),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.count, required this.onReview});

  final int count;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.background,
        border: Border(top: BorderSide(color: theme.colors.border)),
      ),
      child: MaxWidth(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            children: <Widget>[
              const DraftDot(),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      plural('unsaved change', count),
                      style: theme.typography.body.xs.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Kept even if the app closes',
                      style: theme.typography.body.xs3.copyWith(
                        color: theme.colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              FButton(
                size: .sm,
                mainAxisSize: .min,
                onPress: onReview,
                child: const Text('Review and save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
