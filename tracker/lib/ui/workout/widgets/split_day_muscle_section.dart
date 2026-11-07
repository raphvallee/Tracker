import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/services/muscle_set_load.dart';

/// Per-muscle set counts for a split day, listed between the day description
/// and its exercise cards. Rows arrive pre-sorted (see [muscleSetLoads]);
/// muscles only ever hit as secondary targets are muted. Renders nothing when
/// there are no loads.
class SplitDayMuscleSection extends StatelessWidget {
  const SplitDayMuscleSection({super.key, required this.loads});

  final List<MuscleSetLoad> loads;

  @override
  Widget build(BuildContext context) {
    if (loads.isEmpty) return const SizedBox.shrink();
    final colors = context.theme.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final (index, load) in loads.indexed) ...[
          if (index > 0) const SizedBox(height: 8),
          FCard(
            key: ValueKey('muscle-${load.muscle.name}'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      load.muscle.scientificName,
                      style: load.isSecondaryOnly
                          ? TextStyle(color: colors.mutedForeground)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    load.totalSets == 1 ? '1 set' : '${load.totalSets} sets',
                    style: load.isSecondaryOnly
                        ? TextStyle(color: colors.mutedForeground)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}
