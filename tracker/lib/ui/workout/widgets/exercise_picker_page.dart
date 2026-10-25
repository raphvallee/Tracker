import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/keyboard_inset.dart';
import 'package:tracker/ui/core/ui/max_width.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';

/// Picks one exercise from the library for a split day (§1.3.1.1.1). Pops the
/// selected [Exercise] (or null if dismissed).
class ExercisePickerPage extends StatefulWidget {
  const ExercisePickerPage({super.key});

  @override
  State<ExercisePickerPage> createState() => _ExercisePickerPageState();
}

class _ExercisePickerPageState extends State<ExercisePickerPage> {
  List<Exercise> _all = const [];
  List<Exercise> _shown = const [];
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _load();
    }
  }

  Future<void> _load() async {
    final repo = RepositoryScope.maybeOf(context);
    final list = await repo?.exercises.getAll() ?? const <Exercise>[];
    if (!mounted) return;
    setState(() {
      _all = list;
      _shown = list;
    });
  }

  void _filter(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _shown = q.isEmpty
          ? _all
          : _all.where((e) => e.title.toLowerCase().contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: <Widget>[
        CustomAppBar(context, title: 'Pick exercise'),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: MaxWidth(
              child: FTextField(
                hint: 'Search exercises...',
                control: FTextFieldControl.managed(
                  onChange: (value) => _filter(value.text),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          // Keyboard-aware bottom padding (keyboard height + reveal gap): the
          // search field stays pinned at the top while list rows can scroll
          // above the keyboard (the shell Scaffold no longer resizes for the
          // keyboard).
          padding: EdgeInsets.only(bottom: keyboardClearanceOf(context)),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final e = _shown[index];
              return MaxWidth(
                child: FItem(
                  title: Text(e.title),
                  subtitle: Text(
                    e.primaryMuscle.map((m) => m.scientificName).join(', '),
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPress: () => Navigator.of(context).pop(e),
                ),
              );
            }, childCount: _shown.length),
          ),
        ),
      ],
    );
  }
}
