import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/muscle.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/keyboard_inset.dart';

/// Picks the exercise a graph follows; pops it, or nothing when left.
class GraphExercisePickerPage extends StatefulWidget {
  const GraphExercisePickerPage({
    super.key,
    required this.exercises,
    this.selectedId,
  });

  final List<Exercise> exercises;
  final int? selectedId;

  @override
  State<GraphExercisePickerPage> createState() =>
      _GraphExercisePickerPageState();
}

class _GraphExercisePickerPageState extends State<GraphExercisePickerPage> {
  late final TextEditingController _search;
  MuscleGroup? _group;
  List<Exercise> _shown = const [];

  static const _groupOrder = [
    MuscleGroup.chest,
    MuscleGroup.back,
    MuscleGroup.shoulders,
    MuscleGroup.legs,
    MuscleGroup.arms,
    MuscleGroup.abdominals,
  ];

  static const _groupLabels = {
    MuscleGroup.chest: 'Chest',
    MuscleGroup.back: 'Back',
    MuscleGroup.shoulders: 'Shoulders',
    MuscleGroup.legs: 'Legs',
    MuscleGroup.arms: 'Arms',
    MuscleGroup.abdominals: 'Abs',
  };

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
    _refilter();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _refilter() {
    final query = _search.text.trim().toLowerCase();
    Iterable<Exercise> candidates = widget.exercises;
    if (_group != null) {
      candidates = candidates.where((e) => _inGroup(e, _group!));
    }
    _shown =
        candidates.where((e) => e.title.toLowerCase().contains(query)).toList()
          ..sort((a, b) => a.title.compareTo(b.title));
  }

  bool _inGroup(Exercise exercise, MuscleGroup group) => exercise.primaryMuscle
      .any((muscle) => Muscle.muscleToGroup[muscle] == group);

  bool _groupPresent(MuscleGroup group) =>
      widget.exercises.any((exercise) => _inGroup(exercise, group));

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: <Widget>[
        CustomAppBar(context, title: 'Select exercise'),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: FTextField(
              control: FTextFieldControl.managed(
                controller: _search,
                onChange: (_) => setState(_refilter),
              ),
              label: const Text('Search'),
              hint: 'Filter exercises',
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Category',
              style: context.theme.typography.body.sm.copyWith(
                fontWeight: FontWeight.w600,
                color: context.theme.colors.mutedForeground,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FButton(
                  variant: _group == null ? .secondary : .outline,
                  mainAxisSize: MainAxisSize.min,
                  onPress: () => setState(() => _group = null),
                  child: const Text('All'),
                ),
                for (final group in _groupOrder)
                  if (_groupPresent(group))
                    FButton(
                      variant: _group == group ? .secondary : .outline,
                      mainAxisSize: MainAxisSize.min,
                      onPress: () => setState(
                        () => _group = _group == group ? null : group,
                      ),
                      child: Text(_groupLabels[group]!),
                    ),
              ],
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final exercise = _shown[index];
            return FItem(
              prefix: exercise.id == widget.selectedId
                  ? const Icon(FLucideIcons.check, size: 18)
                  : null,
              title: Text(exercise.title),
              subtitle: Text(
                exercise.primaryMuscle.map((m) => m.scientificName).join(', '),
                overflow: TextOverflow.ellipsis,
              ),
              onPress: () => Navigator.of(context).pop(exercise),
            );
          }, childCount: _shown.length),
        ),
        SliverPadding(
          padding: EdgeInsets.only(bottom: keyboardClearanceOf(context)),
          sliver: const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ),
      ],
    );
  }
}
