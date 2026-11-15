import 'package:flutter/widgets.dart';
import 'package:tracker/ui/core/ui/motion.dart';

/// Shows [child] while it is non-null: it grows in when it arrives and
/// shrinks away when it turns null, still showing the last child while it
/// leaves. The room it takes opens and closes with it, top edge first, so
/// whatever sits around it moves instead of jumping. At the bottom of a
/// screen that reads as sliding up from the edge. With [axis] horizontal it
/// opens its width instead, start edge first: beside a button, the button
/// makes room for it.
///
/// A leaving child takes no taps and is gone for screen readers. With
/// reduced motion it comes and goes at once.
class AnimatedReveal extends StatefulWidget {
  const AnimatedReveal({
    super.key,
    required this.child,
    this.fade = true,
    this.axis = Axis.vertical,
    this.appear = false,
  });

  final Widget? child;

  /// The direction its room opens in.
  final Axis axis;

  /// Also fades the child: in as its room opens, out before the room has
  /// closed.
  final bool fade;

  /// Grows the first child in too, instead of showing it at once: for
  /// something that arrives with the widget itself, like a row just added
  /// to a list.
  final bool appear;

  @override
  State<AnimatedReveal> createState() => _AnimatedRevealState();
}

class _AnimatedRevealState extends State<AnimatedReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  // Run backwards on the way out: it eases into place arriving and speeds
  // up leaving.
  late final CurvedAnimation _size = CurvedAnimation(
    parent: _controller,
    curve: Motion.enter,
  );
  late final CurvedAnimation _opacity = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.1, 0.7, curve: Curves.easeOut),
  );

  /// The child, or while it leaves, the last one there was.
  Widget? _shown;

  @override
  void initState() {
    super.initState();
    _shown = widget.child;
    final growIn = widget.appear && _shown != null;
    _controller = AnimationController(
      vsync: this,
      duration: Motion.roomIn,
      reverseDuration: Motion.roomOut,
      value: _shown == null || growIn ? 0 : 1,
    )..addStatusListener(_onStatus);
    if (growIn) _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Arriving with reduced motion on: be there at once.
    if (Motion.reduced(context) && widget.child != null) {
      _controller.value = 1;
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status.isDismissed && _shown != null) setState(() => _shown = null);
  }

  @override
  void didUpdateWidget(AnimatedReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    final child = widget.child;
    final instant = Motion.reduced(context);
    if (child != null) {
      _shown = child;
      instant ? _controller.value = 1 : _controller.forward();
    } else if (instant) {
      _controller.value = 0;
      _shown = null;
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _opacity.dispose();
    _size.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    if (shown == null) return const SizedBox.shrink();
    final leaving = widget.child == null;
    // A leaving child no longer takes taps, nor reads to screen readers.
    Widget revealed = IgnorePointer(
      ignoring: leaving,
      child: ExcludeSemantics(excluding: leaving, child: shown),
    );
    if (widget.fade) {
      revealed = FadeTransition(opacity: _opacity, child: revealed);
    }
    return SizeTransition(
      sizeFactor: _size,
      axis: widget.axis,
      alignment: widget.axis == Axis.vertical
          ? AlignmentDirectional.topStart
          : AlignmentDirectional.centerStart,
      child: revealed,
    );
  }
}
