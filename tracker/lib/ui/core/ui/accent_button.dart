import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
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
    this.trailing,
    this.large = false,
  });

  final String label;
  final VoidCallback? onPress;
  final IconData? prefix;
  final IconData? suffix;

  /// A side note at the button's end, quieter than [label] and split off by
  /// a hairline: the rating a set is logged with.
  final String? trailing;

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
    final main = Row(
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
        padding: EdgeInsets.only(left: 16, right: trailing == null ? 16 : 0),
        decoration: BoxDecoration(
          color: enabled ? accents.live : colors.muted,
          borderRadius: BorderRadius.circular(8),
        ),
        child: trailing == null
            ? main
            : Row(
                children: <Widget>[
                  Expanded(child: main),
                  Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: foreground.withValues(alpha: 0.22),
                        ),
                      ),
                    ),
                    child: Text(
                      trailing!,
                      maxLines: 1,
                      style: context.theme.typography.body.xs.copyWith(
                        color: foreground.withValues(alpha: 0.78),
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
