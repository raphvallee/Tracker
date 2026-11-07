import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/workout_split.dart';

/// Shows an exercise's plan at a glance: a set count caption, then one tile
/// per planned set in order, so the number of sets and each set's rep target
/// read directly from the tiles. Tiles wrap onto new lines on narrow windows.
class PlannedSetsView extends StatelessWidget {
  const PlannedSetsView({
    super.key,
    required this.sets,
    this.captionPrefix = '',
  });

  final List<PlannedSet> sets;

  /// Text placed before the set count, e.g. `Planned: `.
  final String captionPrefix;

  @override
  Widget build(BuildContext context) {
    final setCount = sets.length == 1 ? '1 set' : '${sets.length} sets';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '$captionPrefix$setCount',
          style: context.theme.typography.body.xs.copyWith(
            color: context.theme.colors.mutedForeground,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[for (final set in sets) _SetTile(set: set)],
        ),
      ],
    );
  }
}

class _SetTile extends StatelessWidget {
  const _SetTile({required this.set});

  final PlannedSet set;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    return Container(
      constraints: const BoxConstraints(minWidth: 48),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.muted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            set.repsLabel,
            style: typography.body.sm.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            set.repsUnit,
            style: typography.body.xs.copyWith(color: colors.mutedForeground),
          ),
        ],
      ),
    );
  }
}
