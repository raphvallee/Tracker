import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/muscle.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/keyboard_inset.dart';
import 'package:tracker/utils/form_validators.dart';
import 'package:tracker/ui/core/ui/max_width.dart';

/// Custom exercise creation form (Plan.md §1.4): title, movement pattern,
/// target muscle groups, equipment and a description, persisted to the library
/// via the repository. Pops the created [Exercise] so the caller can react.
class NewExercisePage extends StatefulWidget {
  const NewExercisePage({super.key});

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

  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_primary.isEmpty) {
      showFToast(
        context: context,
        title: const Text('Pick at least one target muscle.'),
        duration: const Duration(seconds: 2),
      );
      return;
    }

    setState(() => _saving = true);
    final repo = RepositoryScope.maybeOf(context);
    final exercise = Exercise(
      title: _title.text.trim(),
      description: _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      primaryMuscle: _primary.toList(),
      secondaryMuscle: _secondary.isEmpty ? null : _secondary.toList(),
      equipment: _equipment.isEmpty
          ? [Equipment.bodyweight]
          : _equipment.toList(),
      movementPattern: _movement,
    );
    if (repo != null) {
      final id = await repo.exercises.put(exercise);
      exercise.id = id;
    }
    if (!mounted) return;
    Navigator.of(context).pop(exercise);
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: <Widget>[
        CustomAppBar(
          context,
          title: 'New Exercise',
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
                      validator: (v) => requiredText(v),
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
