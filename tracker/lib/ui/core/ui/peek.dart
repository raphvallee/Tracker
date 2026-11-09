import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// A card peeking out beside a row, in the row's [Overlay] (a tab's overlay
/// ends above the bottom nav): below the row when it fits, else above.
///
/// A [modal] peek (a long press) dims the page around the row and closes on
/// any tap. Otherwise (a hover) it lets the pointer through, and whoever
/// showed it closes it.
class Peek {
  Peek._(this._open);

  final ValueNotifier<bool> _open;

  bool get isOpen => _open.value;

  /// Shows [builder]'s card beside [anchor]'s render box, as wide as it.
  static Peek show(
    BuildContext anchor, {
    required WidgetBuilder builder,
    bool modal = true,
  }) {
    final overlay = Overlay.of(anchor);
    final overlayBox = overlay.context.findRenderObject()! as RenderBox;
    final box = anchor.findRenderObject()! as RenderBox;
    final rect =
        box.localToGlobal(Offset.zero, ancestor: overlayBox) & box.size;
    final open = ValueNotifier(true);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _PeekLayer(
        anchor: rect,
        modal: modal,
        open: open,
        builder: builder,
        onGone: () {
          entry
            ..remove()
            ..dispose();
          open.dispose();
        },
      ),
    );
    overlay.insert(entry);
    return Peek._(open);
  }

  void close() {
    if (isOpen) _open.value = false;
  }
}

class _PeekLayer extends StatefulWidget {
  const _PeekLayer({
    required this.anchor,
    required this.modal,
    required this.open,
    required this.builder,
    required this.onGone,
  });

  final Rect anchor;
  final bool modal;
  final ValueNotifier<bool> open;
  final WidgetBuilder builder;
  final VoidCallback onGone;

  @override
  State<_PeekLayer> createState() => _PeekLayerState();
}

class _PeekLayerState extends State<_PeekLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    reverseDuration: const Duration(milliseconds: 140),
  )..forward();
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    widget.open.addListener(_onOpen);
  }

  void _onOpen() {
    if (widget.open.value) return;
    _controller.reverse().whenComplete(() {
      if (mounted) widget.onGone();
    });
  }

  @override
  void dispose() {
    widget.open.removeListener(_onOpen);
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _close() {
    if (widget.open.value) widget.open.value = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final card = CustomSingleChildLayout(
      delegate: _PeekPlacement(
        anchor: widget.anchor,
        padding: MediaQuery.paddingOf(context),
      ),
      child: FadeTransition(
        opacity: _curve,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(_curve),
          child: widget.builder(context),
        ),
      ),
    );
    if (!widget.modal) return IgnorePointer(child: card);
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
            onVerticalDragStart: (_) => _close(),
            child: FadeTransition(
              opacity: _curve,
              child: CustomPaint(
                painter: _DimAround(
                  hole: widget.anchor,
                  color: theme.colors.barrier,
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: GestureDetector(onTap: _close, child: card),
        ),
      ],
    );
  }
}

/// Below the anchor when the card fits there, else above it, else on the
/// roomier side; as wide as the anchor and inside the overlay's edges.
class _PeekPlacement extends SingleChildLayoutDelegate {
  _PeekPlacement({required this.anchor, required this.padding});

  final Rect anchor;
  final EdgeInsets padding;

  static const double _gap = 8;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final width = math.min(anchor.width, constraints.maxWidth - 2 * _gap);
    final height =
        constraints.maxHeight - padding.top - padding.bottom - 2 * _gap;
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: math.max(height, 0),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final top = padding.top + _gap;
    final bottom = size.height - padding.bottom - _gap;
    final below = anchor.bottom + _gap;
    final above = anchor.top - _gap - childSize.height;
    final double y;
    if (below + childSize.height <= bottom) {
      y = below;
    } else if (above >= top) {
      y = above;
    } else {
      y = bottom - anchor.bottom > anchor.top - top
          ? math.min(below, bottom - childSize.height)
          : math.max(above, top);
    }
    final x = anchor.left.clamp(_gap, size.width - childSize.width - _gap);
    return Offset(x.toDouble(), y);
  }

  @override
  bool shouldRelayout(_PeekPlacement oldDelegate) =>
      anchor != oldDelegate.anchor || padding != oldDelegate.padding;
}

/// The page dimmed everywhere but the peeked row.
class _DimAround extends CustomPainter {
  _DimAround({required this.hole, required this.color});

  final Rect hole;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRect(hole),
    );
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_DimAround oldDelegate) =>
      hole != oldDelegate.hole || color != oldDelegate.color;
}
