import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/ui/core/themes/accents.dart';
import 'package:tracker/ui/core/ui/animated_reveal.dart';
import 'package:tracker/ui/core/ui/motion.dart';

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
    this.labelKey,
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

  /// What the button stands for, when its label follows what is typed: a
  /// new [labelKey] with a new label crossfades to it (the old one rising
  /// out, the new one rising in), while a new label under the same key is
  /// updated in place, so typing never animates it. Null never animates.
  final Object? labelKey;

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
    // The label and the icon after it are one unit: they crossfade together
    // when the step changes. The icon before it comes and goes from the side,
    // the label gliding over (the check gives way to the rest clock).
    final words = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
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
    final main = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        AnimatedReveal(
          axis: Axis.horizontal,
          child: prefix == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(prefix, size: 18, color: foreground),
                ),
        ),
        Flexible(child: _label(context, words)),
      ],
    );
    return FTappable(
      onPress: onPress,
      builder: (context, states, child) => AnimatedOpacity(
        duration: Motion.of(context, Motion.press),
        curve: Motion.enter,
        opacity: states.contains(FTappableVariant.pressed) ? 0.85 : 1,
        child: child,
      ),
      child: Container(
        height: large ? 52 : 44,
        padding: const EdgeInsets.only(left: 16),
        decoration: BoxDecoration(
          color: enabled ? accents.live : colors.muted,
          borderRadius: BorderRadius.circular(8),
        ),
        // One tree whatever it shows: the rating's cell grows in from the
        // side as the label makes room, and the end padding gives way to it.
        child: Row(
          children: <Widget>[
            Expanded(child: main),
            AnimatedReveal(
              axis: Axis.horizontal,
              fade: false,
              child: trailing == null ? const SizedBox(width: 16) : null,
            ),
            AnimatedReveal(
              axis: Axis.horizontal,
              child: trailing == null
                  ? null
                  : Container(
                      height: large ? 52 : 44,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(BuildContext context, Widget words) {
    final key = labelKey;
    if (key == null) return words;
    return _SwitchingLabel(words: (label, suffix), labelKey: key, child: words);
  }
}

/// [child] crossfading to its next words when [labelKey] changes with them.
class _SwitchingLabel extends StatefulWidget {
  const _SwitchingLabel({
    required this.words,
    required this.labelKey,
    required this.child,
  });

  /// What the label says: its text and the icon after it.
  final Object words;
  final Object labelKey;
  final Widget child;

  @override
  State<_SwitchingLabel> createState() => _SwitchingLabelState();
}

class _SwitchingLabelState extends State<_SwitchingLabel> {
  /// Counts the crossfades: the shown label's key.
  int _generation = 0;

  @override
  void didUpdateWidget(_SwitchingLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new step in new words crossfades. New words for the same step
    // (typing), or the same words for a new one, change in place.
    if (widget.labelKey != oldWidget.labelKey &&
        widget.words != oldWidget.words) {
      _generation++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ValueKey<int>(_generation);
    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.label),
      switchInCurve: Motion.enter,
      switchOutCurve: Motion.exit,
      layoutBuilder: (shown, previous) => Stack(
        alignment: Alignment.center,
        children: <Widget>[...previous, ?shown],
      ),
      transitionBuilder: (child, animation) {
        final incoming = child.key == current;
        // The old label rises out of the way and the new one rises into
        // place: about 6px, a quarter of the text's height.
        final slide = Tween<Offset>(
          begin: Offset(0, incoming ? 0.25 : -0.25),
          end: Offset.zero,
        ).animate(animation);
        return IgnorePointer(
          ignoring: !incoming,
          child: ExcludeSemantics(
            excluding: !incoming,
            child: FadeTransition(
              opacity: animation,
              child: SlideTransition(position: slide, child: child),
            ),
          ),
        );
      },
      child: KeyedSubtree(key: current, child: widget.child),
    );
  }
}
