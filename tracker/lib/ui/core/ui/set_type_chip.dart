import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// W / S chip marking a logged set as warm-up or working. Muted/foreground
/// pairing so the W chip reads on white cards.
class SetTypeChip extends StatelessWidget {
  const SetTypeChip({super.key, required this.isWarmup});

  final bool isWarmup;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final fill = isWarmup ? theme.colors.muted : theme.colors.primary;
    final textColor = isWarmup
        ? theme.colors.mutedForeground
        : theme.colors.primary;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isWarmup ? fill : fill.withValues(alpha: 0.15),
      ),
      child: Text(
        isWarmup ? 'W' : 'S',
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      ),
    );
  }
}
