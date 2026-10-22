import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/data/services/app_log.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/muscle.dart';
import 'package:tracker/ui/core/ui/app_dialog.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/keyboard_inset.dart';
import 'package:tracker/utils/form_validators.dart';
import 'package:tracker/ui/core/ui/max_width.dart';

/// Exercise create/edit form (Plan.md §1.4): title, movement pattern,
/// target muscle groups, equipment and a description, persisted to the library
/// via the repository. Pops the saved [Exercise] so the caller can react.
/// Pass an existing [NewExercisePage.exercise] to rename/edit it in place; the
/// form then also offers a reference-checked delete.
class NewExercisePage extends StatefulWidget {
  const NewExercisePage({super.key, this.exercise});

  /// Existing exercise to edit; null creates a new one.
  final Exercise? exercise;

  @override
  State<NewExercisePage> createState() => _NewExercisePageState();
}

class _NewExercisePageState extends State<NewExercisePage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();

  MovementPattern _movement = MovementPattern.unspecified;
  final Set<Muscle> _primary = {};
  final Set<Muscle> _secondary = {};
  final Set<Equipment> _equipment = {Equipment.bodyweight};

  String? _duplicateError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final exercise = widget.exercise;
    if (exercise != null) {
      _title.text = exercise.title;
      _description.text = exercise.description ?? '';
      _movement = exercise.movementPattern;
      _primary.addAll(exercise.primaryMuscle);
      _secondary.addAll(exercise.secondaryMuscle ?? const []);
      _equipment
        ..clear()
        ..addAll(exercise.equipment);
    }
    // Drop the stale duplicate error as soon as the name changes again.
    _title.addListener(() {
      if (_duplicateError != null) setState(() => _duplicateError = null);
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _duplicateError = null);
    if (!_formKey.currentState!.validate()) return;
    if (_primary.isEmpty) {
      showFToast(
        context: context,
        title: const Text('Pick at least one target muscle.'),
        duration: const Duration(seconds: 2),
      );
      return;
    }

    final repo = RepositoryScope.maybeOf(context);
    final name = _title.text.trim();
    final duplicate = await repo?.exercises.getByTitle(
      name,
      excludeId: widget.exercise?.id,
    );
    if (duplicate != null) {
      setState(() => _duplicateError = '"${duplicate.title}" already exists.');
      _formKey.currentState!.validate();
      return;
    }

    setState(() => _saving = true);
    final exercise =
        widget.exercise ??
        Exercise(title: name, primaryMuscle: const [], equipment: const []);
    exercise
      ..title = name
      ..description = _description.text.trim().isEmpty
          ? null
          : _description.text.trim()
      ..primaryMuscle = _primary.toList()
      ..secondaryMuscle = _secondary.isEmpty ? null : _secondary.toList()
      ..equipment = _equipment.isEmpty
          ? [Equipment.bodyweight]
          : _equipment.toList()
      ..movementPattern = _movement;
    // Error-surfacing contract for writes (mirrors session_detail_page): a
    // failed save keeps the form open with the Save button restored, and the
    // failure is toasted once. Without this the _saving flag would never
    // reset and the form would be stuck.
    try {
      if (repo != null) {
        final id = await repo.exercises.put(exercise);
        exercise.id = id;
      }
      if (!mounted) return;
      Navigator.of(context).pop(exercise);
    } catch (error, stackTrace) {
      AppLog.error('exercise-editor', error, stackTrace);
      if (!mounted) return;
      setState(() => _saving = false);
      showFToast(
        context: context,
        title: const Text('Could not save the changes.'),
        duration: const Duration(seconds: 4),
      );
    }
  }

  /// Deletes the edited exercise. Deletion is blocked while split templates or
  /// logged sessions still reference it; otherwise it asks for confirmation.
  Future<void> _delete() async {
    final exercise = widget.exercise!;
    final repo = RepositoryScope.maybeOf(context);
    if (repo == null) return;

    final splitCount = await repo.splits.countReferencingSplits(exercise.id);
    final sessionCount = await repo.sessions.countLoggingSessions(exercise.id);
    if (!mounted) return;

    final referenced = splitCount + sessionCount > 0;
    final confirmed = await showFDialog<bool>(
      context: context,
      builder: (dialogContext, _, _) => AppDialog(
        title: referenced ? 'Cannot delete exercise' : 'Delete exercise?',
        message: referenced
            ? '"${exercise.title}" is used by $splitCount '
                  'split${splitCount == 1 ? '' : 's'} and $sessionCount '
                  'logged session${sessionCount == 1 ? '' : 's'}. Remove '
                  'it from those first.'
            : 'Remove "${exercise.title}" from the library? '
                  'This cannot be undone.',
        actions: [
          FButton(
            variant: .outline,
            onPress: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          if (!referenced)
            FButton(
              onPress: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
        ],
      ),
    );
    if (confirmed == true) {
      await repo.exercises.delete(exercise.id);
      // Pop without a result; the detail page notices the exercise is gone.
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: <Widget>[
        CustomAppBar(
          context,
          title: widget.exercise == null ? 'New Exercise' : 'Edit Exercise',
          actionButton: _saving ? null : (title: 'Save', onPressed: _save),
        ),
        SliverToBoxAdapter(
          child: Padding(
            // Bottom padding tracks the keyboard so the focused field and the
            // trailing selects can scroll above it (shell no longer resizes).
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + keyboardInsetOf(context),
            ),
            child: MaxWidth(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    FTextFormField(
                      control: FTextFieldControl.managed(controller: _title),
                      label: const Text('Name'),
                      validator: (v) => _duplicateError ?? requiredText(v),
                    ),
                    const SizedBox(height: 16),
                    FTextFormField(
                      control: FTextFieldControl.managed(
                        controller: _description,
                      ),
                      label: const Text('Description (optional)'),
                      minLines: 1,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                    ),
                    const SizedBox(height: 16),
                    FSelect<MovementPattern>(
                      label: const Text('Movement pattern'),
                      items: {
                        for (final m in MovementPattern.values)
                          _movementLabel(m): m,
                      },
                      control: FSelectControl<MovementPattern>.lifted(
                        value: _movement,
                        onChange: (v) =>
                            setState(() => _movement = v ?? _movement),
                      ),
                    ),
                    _MuscleSelectGroup(
                      label: 'Primary muscles',
                      selected: _primary,
                      onChange: (sel) => setState(
                        () => _primary
                          ..clear()
                          ..addAll(sel),
                      ),
                    ),
                    _MuscleSelectGroup(
                      label: 'Secondary muscles (optional)',
                      selected: _secondary,
                      onChange: (sel) => setState(
                        () => _secondary
                          ..clear()
                          ..addAll(sel),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Equipment', style: context.theme.typography.body.sm),
                    const SizedBox(height: 8),
                    _EquipmentSelectGroup(
                      selected: _equipment,
                      onChange: (sel) => setState(
                        () => _equipment
                          ..clear()
                          ..addAll(sel),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (widget.exercise != null) ...[
                      FButton(
                        variant: .outline,
                        onPress: _saving ? null : _delete,
                        child: const Text('Delete exercise'),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _movementLabel(MovementPattern m) => switch (m) {
    MovementPattern.unspecified => 'Unspecified',
    MovementPattern.push => 'Push',
    MovementPattern.pull => 'Pull',
    MovementPattern.legs => 'Legs',
    MovementPattern.core => 'Core',
    MovementPattern.fullBody => 'Full body',
  };
}

class _MuscleSelectGroup extends StatelessWidget {
  const _MuscleSelectGroup({
    required this.label,
    required this.selected,
    required this.onChange,
  });

  final String label;
  final Set<Muscle> selected;
  final ValueChanged<Set<Muscle>> onChange;

  @override
  Widget build(BuildContext context) {
    return FSelectGroup<Muscle>(
      label: Text(label),
      control: FMultiValueControl<Muscle>.lifted(
        value: selected,
        onChange: onChange,
      ),
      children: [
        for (final m in Muscle.values)
          FSelectGroupItemMixin.checkbox(
            value: m,
            label: Text(m.scientificName),
          ),
      ],
    );
  }
}

class _EquipmentSelectGroup extends StatelessWidget {
  const _EquipmentSelectGroup({required this.selected, required this.onChange});

  final Set<Equipment> selected;
  final ValueChanged<Set<Equipment>> onChange;

  @override
  Widget build(BuildContext context) {
    return FSelectGroup<Equipment>(
      control: FMultiValueControl<Equipment>.lifted(
        value: selected,
        onChange: onChange,
      ),
      children: [
        for (final e in Equipment.values)
          FSelectGroupItemMixin.checkbox(value: e, label: Text(e.displayName)),
      ],
    );
  }
}
