import 'package:flutter/widgets.dart';
import 'package:tracker/ui/core/ui/motion.dart';

/// Where a row's motion stands (see [RowMotion]).
class RowMotionValues {
  const RowMotionValues({
    required this.open,
    required this.openParts,
    required this.foldedParts,
  });

  /// 0 folded, 1 open: the frame, the shared parts' places and the room the
  /// row takes. Build both looks from it, interpolating what they share.
  final double open;

  /// How visible the open look's own parts are (its labels, its controls):
  /// they come in over the last 60 % of the opening and go in the first
  /// 30 % of the folding.
  final double openParts;

  /// How visible the folded look's own parts are: they go in the first 30 %
  /// of the opening and come back over the last 60 % of the folding.
  final double foldedParts;
}

/// Moves a row between a folded and an open look over 220 ms
/// (`docs/MOTION.md`). Folding mirrors opening (the same curve, backwards),
/// so when one row folds as another opens, what one gives up the other
/// takes at every frame and the rows below stay put. Each look's own parts
/// fade out early and in late, so it reads as one row closing, then the
/// next opening. With reduced motion every change is immediate.
///
/// The exercise page's set row runs the same timings with two more channels
/// (logged, comparison) of its own.
class RowMotion extends StatefulWidget {
  const RowMotion({
    super.key,
    required this.open,
    required this.builder,
    this.onOpening,
  });

  final bool open;
  final Widget Function(BuildContext context, RowMotionValues motion) builder;

  /// Called each frame the row opens, with the row's context and the share
  /// of what was left of the way that frame covered: 1 once it is open, on
  /// the frame after, against the final layout. See [followOpening].
  final void Function(BuildContext context, double share)? onOpening;

  @override
  State<RowMotion> createState() => _RowMotionState();
}

class _RowMotionState extends State<RowMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.state,
    value: widget.open ? 1 : 0,
  );
  late final CurvedAnimation _open = CurvedAnimation(
    parent: _controller,
    curve: Motion.enter,
    reverseCurve: Motion.exit,
  );
  late final CurvedAnimation _openParts = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.4, 1, curve: Curves.easeOut),
    reverseCurve: const Interval(0.7, 1),
  );
  late final CurvedAnimation _foldedAway = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.3),
    reverseCurve: const Interval(0, 0.6, curve: Curves.easeIn),
  );

  /// How open the row was on the last frame [RowMotion.onOpening] saw.
  double _followed = 0;

  @override
  void initState() {
    super.initState();
    _controller
      ..addListener(_onFrame)
      ..addStatusListener(_onStatus);
  }

  void _onFrame() {
    if (_controller.status != AnimationStatus.forward) return;
    final now = _open.value;
    final left = 1 - _followed;
    if (left > 0) {
      widget.onOpening?.call(
        context,
        ((now - _followed) / left).clamp(0.0, 1.0),
      );
    }
    _followed = now;
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.forward) {
      _followed = _open.value;
    } else if (status == AnimationStatus.completed &&
        widget.onOpening != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.open) widget.onOpening?.call(context, 1);
      });
    }
  }

  @override
  void didUpdateWidget(RowMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open == oldWidget.open) return;
    if (Motion.reduced(context)) {
      _controller.value = widget.open ? 1 : 0;
    } else if (widget.open) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _foldedAway.dispose();
    _openParts.dispose();
    _open.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => widget.builder(
      context,
      RowMotionValues(
        open: _open.value,
        openParts: _openParts.value,
        foldedParts: 1 - _foldedAway.value,
      ),
    ),
  );
}

/// Keeps a row that is opening clear of whatever covers the page's bottom
/// ([visibleBottom], in global coordinates: a dock, a keypad, a bar). Each
/// frame it scrolls [share] of what still hides of the row, so the page
/// moves with the row as it grows, in one motion, and the whole row is in
/// view once it is open. Use it as [RowMotion.onOpening].
void followOpening(
  BuildContext rowContext,
  double share, {
  required double visibleBottom,
}) {
  if (share <= 0) return;
  final box = rowContext.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return;
  final scrollable = Scrollable.maybeOf(rowContext);
  if (scrollable == null) return;
  // A little room under the row, so its outline never meets the edge.
  final bottom = box.localToGlobal(Offset(0, box.size.height)).dy + 12;
  final hidden = bottom - visibleBottom;
  if (hidden <= 0.5) return;
  final position = scrollable.position;
  final target = (position.pixels + hidden * share).clamp(
    position.minScrollExtent,
    position.maxScrollExtent,
  );
  if (share < 1 || Motion.reduced(rowContext)) {
    position.jumpTo(target);
  } else {
    // Once open, against its final layout: what the last frames left.
    position.animateTo(target, duration: Motion.label, curve: Motion.enter);
  }
}
