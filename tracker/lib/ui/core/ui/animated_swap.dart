import 'package:flutter/widgets.dart';
import 'package:tracker/ui/core/ui/motion.dart';

/// Swaps [child] for the next one when its key changes, for content that
/// is replaced rather than changed (another day's plan, another page of
/// results): the old one fades out over the first 30 % of the swap, the
/// new one fades in over the last 60 %, and the room they take moves once
/// from the old height to the new on the same 220 ms (`docs/MOTION.md`, M5).
/// The leaving child takes no taps and reads to no one. With reduced motion
/// the new child is there at once.
class AnimatedSwap extends StatelessWidget {
  const AnimatedSwap({super.key, required this.child});

  /// Give it a key that names what it shows: a new key swaps.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = Motion.of(context, Motion.state);
    return AnimatedSize(
      duration: duration,
      curve: Motion.enter,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: const Interval(0.4, 1, curve: Curves.easeOut),
        switchOutCurve: const Interval(0.7, 1),
        // Only the arriving child sizes the room; the leaving one is laid
        // over it while it fades.
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: <Widget>[
            for (final child in previous)
              Positioned(top: 0, left: 0, right: 0, child: child),
            ?current,
          ],
        ),
        transitionBuilder: (shown, animation) {
          final leaving = shown.key != child.key;
          return IgnorePointer(
            ignoring: leaving,
            child: ExcludeSemantics(
              excluding: leaving,
              child: FadeTransition(opacity: animation, child: shown),
            ),
          );
        },
        child: child,
      ),
    );
  }
}
