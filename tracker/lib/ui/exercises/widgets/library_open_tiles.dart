import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/services/exercise_library.dart';
import 'package:tracker/ui/core/ui/animated_reveal.dart';
import 'package:tracker/ui/core/ui/item_card.dart';
import 'package:tracker/ui/exercises/widgets/exercise_list_page.dart';
import 'package:tracker/ui/exercises/widgets/library_parts.dart';

/// The library as tiles that open in place: recently trained exercises on
/// top, then a tile per muscle group with a dash per exercise, filled when
/// it is in the current split, or a tile per day of that split with what
/// it works. A tap opens the group's exercises right below its row of
/// tiles, pointed at by a notch; another tap, or a tap on another tile,
/// closes it.
class LibraryOpenTiles extends StatefulWidget {
  const LibraryOpenTiles({super.key, required this.source});

  final ValueListenable<ExerciseLibrary> source;

  /// How many exercises an open group lists before "Show N more".
  static const int shownAtFirst = 5;

  @override
  State<LibraryOpenTiles> createState() => _LibraryOpenTilesState();
}

class _LibraryOpenTilesState extends State<LibraryOpenTiles> {
  ExerciseGrouping _grouping = ExerciseGrouping.muscle;
  String? _open;
  bool _showAll = false;

  void _toggle(LibraryGroup group) => setState(() {
    _open = _open == group.key ? null : group.key;
    _showAll = false;
  });

  void _switchGrouping() => setState(() {
    _grouping = _grouping == ExerciseGrouping.muscle
        ? ExerciseGrouping.splitDay
        : ExerciseGrouping.muscle;
    _open = null;
    _showAll = false;
  });

  @override
  Widget build(BuildContext context) {
    final library = widget.source.value;
    final split = library.split;
    final days = library.groupsBy(ExerciseGrouping.splitDay);
    // Without a split (or one with no exercises) only muscles are left.
    final byMuscle = _grouping == ExerciseGrouping.muscle || days.isEmpty;
    final grouping = byMuscle
        ? ExerciseGrouping.muscle
        : ExerciseGrouping.splitDay;
    final groups = library.groupsBy(grouping);
    final hasRecent = library.recentlyTrained.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (hasRecent) ...[
          HubHeading(
            title: 'Recently trained',
            action: 'All ${library.exercises.length}',
            onAction: () => openAllExercises(context, widget.source),
          ),
          RecentStrip(library: library),
        ],
        HubHeading(
          title: byMuscle ? 'By muscle' : split!.title,
          action: byMuscle
              ? (days.isEmpty ? null : 'By split day')
              : 'By muscle',
          onAction: _switchGrouping,
        ),
        LayoutBuilder(
          builder: (context, constraints) => _grid(
            context,
            library,
            groups,
            constraints.maxWidth,
            splitDays: !byMuscle,
          ),
        ),
        if (!hasRecent)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: PressFade(
                onPress: () => openAllExercises(context, widget.source),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'All ${library.exercises.length} exercises',
                    style: context.theme.typography.body.xs.copyWith(
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _grid(
    BuildContext context,
    ExerciseLibrary library,
    List<LibraryGroup> groups,
    double width, {
    required bool splitDays,
  }) {
    final coverage = !splitDays && library.split != null;
    const gap = TileGrid.gap;
    final columns = TileGrid.columnsFor(width);
    final cellWidth = (width - gap * (columns - 1)) / columns;
    final cells = <Widget>[
      for (final group in groups)
        _GroupTile(
          key: ValueKey<String>('exercise-group-${group.key}'),
          group: group,
          open: group.key == _open,
          coverage: coverage,
          splitDay: splitDays,
          onPress: () => _toggle(group),
        ),
      const NewExerciseTile(),
    ];
    final rows = <Widget>[];
    for (var row = 0; row < cells.length; row += columns) {
      if (row > 0) rows.add(const SizedBox(height: gap));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (var i = row; i < row + columns; i++) ...[
                if (i > row) const SizedBox(width: gap),
                Expanded(
                  child: i < cells.length ? cells[i] : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
      LibraryGroup? open;
      var column = 0;
      for (var i = row; i < row + columns && i < groups.length; i++) {
        if (groups[i].key == _open) {
          open = groups[i];
          column = i - row;
        }
      }
      rows.add(
        AnimatedReveal(
          key: ValueKey<String>('open-row-$row'),
          child: open == null
              ? null
              : _OpenGroup(
                  key: ValueKey<String>('open-${open.key}'),
                  library: library,
                  group: open,
                  coverage: coverage,
                  splitDay: splitDays,
                  notchAt: column * (cellWidth + gap) + cellWidth / 2,
                  showAll: _showAll,
                  onShowAll: () => setState(() => _showAll = true),
                ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({
    super.key,
    required this.group,
    required this.open,
    required this.coverage,
    required this.splitDay,
    required this.onPress,
  });

  final LibraryGroup group;
  final bool open;

  /// Shows how many of its exercises are in the current split.
  final bool coverage;

  /// A day of the current split: shows what it works instead.
  final bool splitDay;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final total = group.exercises.length;
    return Semantics(
      expanded: open,
      child: PressFade(
        onPress: onPress,
        selected: open,
        semanticsLabel: [
          group.title,
          exerciseCount(total),
          if (coverage) inSplitLabel(group.inSplit, total).toLowerCase(),
          if (splitDay) worksLabel(group).toLowerCase(),
        ].join(', '),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: tileDecoration(context, selected: open),
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        group.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.body.md.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        FLucideIcons.chevronDown,
                        size: 16,
                        color: theme.colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
                Text(
                  exerciseCount(total),
                  style: theme.typography.body.xs.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
                if (coverage) ...[
                  const SizedBox(height: 14),
                  CoverageBar(filled: group.inSplit, total: total),
                ] else if (splitDay) ...[
                  const SizedBox(height: 8),
                  Text(
                    worksLabel(group),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.body.xs.copyWith(
                      color: theme.colors.foreground,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A group's exercises below its row of tiles, with a notch pointing up at
/// [notchAt] (the middle of its tile).
class _OpenGroup extends StatelessWidget {
  const _OpenGroup({
    super.key,
    required this.library,
    required this.group,
    required this.coverage,
    required this.splitDay,
    required this.notchAt,
    required this.showAll,
    required this.onShowAll,
  });

  final ExerciseLibrary library;
  final LibraryGroup group;
  final bool coverage;
  final bool splitDay;
  final double notchAt;
  final bool showAll;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final exercises = group.exercises;
    final shown = showAll || exercises.length <= LibraryOpenTiles.shownAtFirst
        ? exercises
        : exercises.take(LibraryOpenTiles.shownAtFirst).toList();
    final hidden = exercises.length - shown.length;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              ItemCard(
                divider: .full,
                children: [
                  for (final exercise in shown)
                    exerciseItem(
                      context,
                      library,
                      exercise,
                      marksSplit: !splitDay,
                    ),
                  if (hidden > 0)
                    FItem(
                      key: ValueKey<String>('show-more-${group.key}'),
                      title: Center(
                        child: Text(
                          'Show $hidden more',
                          style: theme.typography.body.sm.copyWith(
                            color: theme.colors.mutedForeground,
                          ),
                        ),
                      ),
                      onPress: onShowAll,
                    ),
                ],
              ),
              Positioned(
                top: -6,
                left: notchAt - 7,
                child: CustomPaint(
                  size: const Size(14, 7),
                  painter: _Notch(
                    fill: theme.colors.card,
                    line: theme.colors.border,
                  ),
                ),
              ),
            ],
          ),
          if (coverage)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
              child: Text(
                inSplitLabel(group.inSplit, exercises.length),
                textAlign: TextAlign.right,
                style: theme.typography.body.xs.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            )
          else
            const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _Notch extends CustomPainter {
  const _Notch({required this.fill, required this.line});

  final Color fill;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // The fill runs a pixel past the base to cover the card's own outline.
    canvas.drawPath(
      Path()
        ..moveTo(0, h + 1)
        ..lineTo(w / 2, 0)
        ..lineTo(w, h + 1)
        ..close(),
      Paint()..color = fill,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, h)
        ..lineTo(w / 2, 0)
        ..lineTo(w, h),
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_Notch old) => fill != old.fill || line != old.line;
}
