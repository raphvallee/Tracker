import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// Icon-only action button: a ghost [FButton] with a hover tooltip.
///
/// Replaces Material's [IconButton] so icon actions stay themed by Forui.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPress,
    this.color,
    this.size = .md,
    this.compact = false,
  });

  final IconData icon;

  /// Hover tooltip text; also exposed as the button's semantics tooltip.
  final String tooltip;

  final VoidCallback? onPress;

  /// Overrides the theme's icon color, e.g. a destructive red.
  final Color? color;

  final FButtonSizeVariant size;

  /// Strips the button's content padding and minimum-size constraints so the
  /// icon fits tight fixed-width cells (e.g. the split editor's 28px grid).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final button = FButton(
      // Shrink-wrap: inside an FItem suffix slot, a max-size button would
      // expand and starve the item's title/subtitle (see FItem's docs).
      mainAxisSize: .min,
      size: size,
      variant: .ghost,
      semanticsTooltip: tooltip,
      onPress: onPress,
      style: compact
          ? .delta(
              contentStyle: .delta(
                padding: const .value(EdgeInsetsGeometry.zero),
                constraints: const BoxConstraints(),
              ),
            )
          : const .context(),
      child: Icon(icon, color: color),
    );
    return FTooltip(tipBuilder: (_, _) => Text(tooltip), child: button);
  }
}
