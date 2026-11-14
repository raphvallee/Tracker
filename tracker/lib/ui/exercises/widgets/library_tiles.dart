import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/services/exercise_library.dart';
import 'package:tracker/ui/core/ui/item_card.dart';
import 'package:tracker/ui/exercises/widgets/exercise_list_page.dart';
import 'package:tracker/ui/exercises/widgets/library_parts.dart';

/// What the tiles layout sorts the library by.
enum _View {
  muscle('Muscle', ExerciseGrouping.muscle),
  split('Split', ExerciseGrouping.splitDay),
  equipment('Equipment', ExerciseGrouping.equipment),
  recent('Recent', null);

  const _View(this.label, this.grouping);

  final String label;
  final ExerciseGrouping? grouping;
}

/// The library as tiles: a switch between muscle, the current split's days,
/// equipment and recent, then a tile per group broken down by muscle (by
/// muscle group for split days and equipment). Muscle and equipment tiles
/// give each line a square per exercise, filled when it is in the current
/// split; a split day's tiles count them instead. A tile opens its group on
/// a page of its own; Recent lists the exercises trained, latest first.
class LibraryTiles extends StatefulWidget {
  const LibraryTiles({super.key, required this.source});

  final ValueListenable<ExerciseLibrary> source;

  @override
  State<LibraryTiles> createState() => _LibraryTilesState();
}

class _LibraryTilesState extends State<LibraryTiles> {
  _View _view = _View.muscle;

  @override
  Widget build(BuildContext context) {
    final library = widget.source.value;
    final hasDays = library.groupsBy(ExerciseGrouping.splitDay).isNotEmpty;
    // Without a split (or one with no exercises) there is no Split view.
    final view = _view == _View.split && !hasDays ? _View.muscle : _view;
    final grouping = view.grouping;
    final squares =
        library.split != null && grouping != ExerciseGrouping.splitDay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 12),
        _Segments(
          views: [
            for (final view in _View.values)
              if (view != _View.split || hasDays) view,
          ],
          selected: view,
          onSelect: (view) => setState(() => _view = view),
        ),
        const SizedBox(height: 12),
        if (grouping != null)
          TileGrid(
            cells: [
              for (final group in library.groupsBy(grouping))
                _GroupTile(
                  key: ValueKey<String>('exercise-group-${group.key}'),
                  group: group,
                  squares: squares,
                  onPress: () =>
                      openGroup(context, widget.source, grouping, group),
                ),
              const NewExerciseTile(minHeight: 118),
            ],
          )
        else
          _recent(context, library),
      ],
    );
  }

  Widget _recent(BuildContext context, ExerciseLibrary library) {
    final theme = context.theme;
    final recent = library.recentlyTrained;
    if (recent.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
        child: Text(
          'Nothing trained yet. The exercises you log show up here, the '
          'latest first.',
          textAlign: TextAlign.center,
          style: theme.typography.body.sm.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
      );
    }
    return ItemCard(
      divider: .full,
      children: [
        for (final exercise in recent) exerciseItem(context, library, exercise),
      ],
    );
  }
}

/// A switch between the views, one segment each, the selected one raised.
class _Segments extends StatelessWidget {
  const _Segments({
    required this.views,
    required this.selected,
    required this.onSelect,
  });

  final List<_View> views;
  final _View selected;
  final ValueChanged<_View> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = theme.colors;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.secondary,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          for (final view in views)
            Expanded(
              child: PressFade(
                key: ValueKey<String>('library-view-${view.name}'),
                selected: view == selected,
                onPress: () => onSelect(view),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: view == selected ? colors.card : null,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: view == selected
                          ? colors.border
                          : const Color(0x00000000),
                    ),
                  ),
                  child: Text(
                    view.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.body.xs.copyWith(
                      fontWeight: FontWeight.w500,
                      color: view == selected
                          ? colors.foreground
                          : colors.mutedForeground,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({
    super.key,
    required this.group,
    required this.squares,
    required this.onPress,
  });

  final LibraryGroup group;

  /// Each line shows a square per exercise, filled when it is in the
  /// current split; otherwise how many exercises it has.
  final bool squares;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final muted = theme.typography.body.xs.copyWith(
      color: theme.colors.mutedForeground,
    );
    final total = group.exercises.length;
    return PressFade(
      onPress: onPress,
      semanticsLabel: squares
          ? '${group.title}, ${exerciseCount(total)}, '
                '${inSplitLabel(group.inSplit, total).toLowerCase()}'
          : '${group.title}, ${exerciseCount(total)}',
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
        decoration: tileDecoration(context),
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                group.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.body.md.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              Text(exerciseCount(total), style: muted),
              const SizedBox(height: 10),
              for (final part in group.parts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          part.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: muted,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (squares)
                        SquareCount(filled: part.inSplit, total: part.total)
                      else
                        Text('${part.total}', style: muted),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
