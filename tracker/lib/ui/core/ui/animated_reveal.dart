import 'package:flutter/widgets.dart';

/// Shows [child] while it is non-null: it grows in when it arrives and
/// shrinks away when it turns null, still showing the last child while it
/// leaves. The room it takes opens and closes with it, top edge first, so
/// whatever sits around it moves instead of jumping. At the bottom of a
/// screen that reads as sliding up from the edge.
class AnimatedReveal extends StatefulWidget {
  const AnimatedReveal({super.key, required this.child, this.fade = true});

  final Widget? child;

  /// Also fades the child: in as its room opens, out before the room has
  /// closed.
  final bool fade;

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
    curve: Curves.easeOutCubic,
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
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 240),
      value: _shown == null ? 0 : 1,
    )..addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    if (status.isDismissed && _shown != null) setState(() => _shown = null);
  }

  @override
  void didUpdateWidget(AnimatedReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    final child = widget.child;
    if (child != null) {
      _shown = child;
      _controller.forward();
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
    // A leaving child no longer takes taps.
    Widget revealed = IgnorePointer(
      ignoring: widget.child == null,
      child: shown,
    );
    if (widget.fade) {
      revealed = FadeTransition(opacity: _opacity, child: revealed);
    }
    return SizeTransition(
      sizeFactor: _size,
      alignment: AlignmentDirectional.topStart,
      child: revealed,
    );
  }
}
