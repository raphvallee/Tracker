import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/ui/core/themes/accents.dart';

/// A full-width button filled with the live accent: the actions that start
/// or advance a workout (Start, Continue, Log).
class AccentButton extends StatelessWidget {
  const AccentButton({
    super.key,
    required this.label,
    required this.onPress,
    this.prefix,
    this.suffix,
    this.large = false,
  });

  final String label;
  final VoidCallback? onPress;
  final IconData? prefix;
  final IconData? suffix;

  /// 52px tall instead of 44px, for the one main action of a screen.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final accents = TrackerAccents.of(context);
    final colors = context.theme.colors;
    final enabled = onPress != null;
    final foreground = enabled
        ? accents.liveForeground
        : colors.mutedForeground;
    final text = context.theme.typography.body.sm.copyWith(
      color: foreground,
      fontWeight: FontWeight.w600,
      height: 1.2,
    );
    return FTappable(
      onPress: onPress,
      builder: (context, states, child) => AnimatedOpacity(
        duration: const Duration(milliseconds: 100),
        opacity: states.contains(FTappableVariant.pressed) ? 0.85 : 1,
        child: child,
      ),
      child: Container(
        height: large ? 52 : 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: enabled ? accents.live : colors.muted,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (prefix != null) ...[
              Icon(prefix, size: 18, color: foreground),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                style: text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (suffix != null) ...[
              const SizedBox(width: 8),
              Icon(suffix, size: 18, color: foreground),
            ],
          ],
        ),
      ),
    );
  }
}
