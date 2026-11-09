import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A column, its children stretched to its width, whose children slide to
/// their new places when their order changes instead of jumping there.
/// Children need keys that stay with them. Children moving up, and children
/// that arrive with the change, pass over the others, so give children that
/// can overlap mid-slide an opaque background.
class SlidingColumn extends StatefulWidget {
  const SlidingColumn({
    super.key,
    required this.children,
    this.duration = const Duration(milliseconds: 420),
    this.curve = Curves.easeInOutCubic,
  });

  final List<Widget> children;
  final Duration duration;
  final Curve curve;

  @override
  State<SlidingColumn> createState() => _SlidingColumnState();
}

class _SlidingColumnState extends State<SlidingColumn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  );
  late final CurvedAnimation _progress = CurvedAnimation(
    parent: _controller,
    curve: widget.curve,
  );

  /// Bumped on every order change: the render object then slides each child
  /// from where it was painted.
  int _changes = 0;

  @override
  void didUpdateWidget(SlidingColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    _progress.curve = widget.curve;
    if (!_sameOrder(oldWidget.children, widget.children)) {
      _changes++;
      _controller.forward(from: 0);
    }
  }

  static bool _sameOrder(List<Widget> a, List<Widget> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].key != b[i].key) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _progress.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.children.every((child) => child.key != null),
      'SlidingColumn children need keys that stay with them.',
    );
    return _Slides(
      progress: _progress,
      changes: _changes,
      children: <Widget>[
        for (final child in widget.children)
          RepaintBoundary(key: ValueKey<Key>(child.key!), child: child),
      ],
    );
  }
}

class _Slides extends MultiChildRenderObjectWidget {
  const _Slides({
    required this.progress,
    required this.changes,
    required super.children,
  });

  final Animation<double> progress;
  final int changes;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSlides(progress, changes);

  @override
  void updateRenderObject(BuildContext context, _RenderSlides renderObject) {
    renderObject
      ..progress = progress
      ..changes = changes;
  }
}

class _SlideParentData extends ContainerBoxParentData<RenderBox> {
  bool laidOut = false;

  /// Where the child was painted when the order last changed; null when it
  /// arrived with that change.
  Offset? from;

  /// Arrived with the last order change.
  bool arrived = false;

  /// What the last paint added to [offset].
  Offset shift = Offset.zero;

  Offset get painted => offset + shift;
}

class _RenderSlides extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _SlideParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _SlideParentData> {
  _RenderSlides(this._progress, this._changes);

  Animation<double> _progress;
  set progress(Animation<double> value) {
    if (identical(value, _progress)) return;
    if (attached) {
      _progress.removeListener(markNeedsPaint);
      value.addListener(markNeedsPaint);
    }
    _progress = value;
    markNeedsPaint();
  }

  int _changes;
  bool _slideNextLayout = false;
  set changes(int value) {
    if (value == _changes) return;
    _changes = value;
    _slideNextLayout = true;
    markNeedsLayout();
  }

  // Repaints every frame of a slide: keep that to this layer.
  @override
  bool get isRepaintBoundary => true;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _SlideParentData) {
      child.parentData = _SlideParentData();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _progress.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _progress.removeListener(markNeedsPaint);
    super.detach();
  }

  BoxConstraints _childConstraints(BoxConstraints constraints) =>
      constraints.hasBoundedWidth
      ? BoxConstraints.tightFor(width: constraints.maxWidth)
      : const BoxConstraints();

  @override
  void performLayout() {
    final childConstraints = _childConstraints(constraints);
    var y = 0.0;
    var width = 0.0;
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as _SlideParentData;
      if (_slideNextLayout) {
        // Still holds last frame's layout and paint: start from there.
        data
          ..from = data.laidOut ? data.painted : null
          ..arrived = !data.laidOut;
      }
      child.layout(childConstraints, parentUsesSize: true);
      data
        ..offset = Offset(0, y)
        ..laidOut = true;
      y += child.size.height;
      if (child.size.width > width) width = child.size.width;
      child = data.nextSibling;
    }
    _slideNextLayout = false;
    size = constraints.constrain(
      Size(constraints.hasBoundedWidth ? constraints.maxWidth : width, y),
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final childConstraints = _childConstraints(constraints);
    var y = 0.0;
    var width = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      final size = child.getDryLayout(childConstraints);
      y += size.height;
      if (size.width > width) width = size.width;
    }
    return constraints.constrain(
      Size(constraints.hasBoundedWidth ? constraints.maxWidth : width, y),
    );
  }

  double _sum(double Function(RenderBox child) of) {
    var total = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      total += of(child);
    }
    return total;
  }

  double _widest(double Function(RenderBox child) of) {
    var widest = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      final width = of(child);
      if (width > widest) widest = width;
    }
    return widest;
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _widest((child) => child.getMinIntrinsicWidth(double.infinity));

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _widest((child) => child.getMaxIntrinsicWidth(double.infinity));

  @override
  double computeMinIntrinsicHeight(double width) =>
      _sum((child) => child.getMinIntrinsicHeight(width));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _sum((child) => child.getMaxIntrinsicHeight(width));

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToFirstActualBaseline(baseline);

  bool get _sliding => _progress.value < 1;

  Offset _shiftOf(_SlideParentData data) {
    final from = data.from;
    if (from == null || !_sliding) return Offset.zero;
    return (from - data.offset) * (1 - _progress.value);
  }

  /// Painted over the others: moving up (still below its place), or new.
  bool _onTop(_SlideParentData data) =>
      _sliding && (data.shift.dy > 0 || data.arrived);

  @override
  void paint(PaintingContext context, Offset offset) {
    for (var child = firstChild; child != null; child = childAfter(child)) {
      final data = child.parentData! as _SlideParentData;
      data.shift = _shiftOf(data);
      if (!_onTop(data)) context.paintChild(child, offset + data.painted);
    }
    for (var child = firstChild; child != null; child = childAfter(child)) {
      final data = child.parentData! as _SlideParentData;
      if (_onTop(data)) context.paintChild(child, offset + data.painted);
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final at = (child.parentData! as _SlideParentData).painted;
    transform.translateByDouble(at.dx, at.dy, 0, 1);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    // Front to back: the reverse of the paint order.
    for (final onTop in [true, false]) {
      for (var child = lastChild; child != null; child = childBefore(child)) {
        final data = child.parentData! as _SlideParentData;
        if (_onTop(data) != onTop) continue;
        final hitChild = child;
        final hit = result.addWithPaintOffset(
          offset: data.painted,
          position: position,
          hitTest: (result, transformed) =>
              hitChild.hitTest(result, position: transformed),
        );
        if (hit) return true;
      }
    }
    return false;
  }
}
