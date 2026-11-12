import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/ui/core/ui/dashed_outline.dart';

/// A set's mark at the start of its row: its number among the working sets,
/// or W for a warm-up, in a small outlined circle, dashed for a warm-up.
class SetBadge extends StatelessWidget {
  const SetBadge({
    super.key,
    required this.label,
    required this.warmup,
    this.size = 22,
  });

  final String label;
  final bool warmup;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final muted = theme.colors.mutedForeground;
    final text = Center(
      child: Text(
        label,
        maxLines: 1,
        style: theme.typography.body.xs3.copyWith(
          fontSize: 11,
          height: 1,
          fontWeight: FontWeight.w600,
          color: muted,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    return SizedBox.square(
      dimension: size,
      child: warmup
          ? CustomPaint(
              painter: DashedOutline(
                color: muted,
                radius: size / 2,
                dash: 2.5,
                gap: 2,
              ),
              child: text,
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: theme.colors.border),
              ),
              child: text,
            ),
    );
  }
}
