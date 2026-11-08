import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/workout_split.dart';

class PlannedSetsView extends StatelessWidget {
  const PlannedSetsView({super.key, required this.sets});

  final List<PlannedSet> sets;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[for (final set in sets) _SetTile(set: set)],
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
