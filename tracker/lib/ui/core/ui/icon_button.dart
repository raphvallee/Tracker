import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

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

  final String tooltip;

  final VoidCallback? onPress;

  final Color? color;

  final FButtonSizeVariant size;

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
