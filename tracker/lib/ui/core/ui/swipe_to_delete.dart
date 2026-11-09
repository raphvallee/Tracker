import 'dart:math' as math;

import 'package:flutter/gestures.dart' show HitTestResult;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderMetaData;
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:forui/forui.dart';

/// Deletes a row in two swipes, so a stray flick never loses anything: the
/// first swipe left slides the row open on a red Delete action, the second
/// (or a tap on Delete) slides it out and removes it. Open, a tap on the row,
/// a tap anywhere else or a swipe back right closes it again.
///
/// Works off raw [Listener] pointer events rather than the gesture arena:
/// rows full of text fields would otherwise win the horizontal drag
/// themselves and never let a swipe through. A [SwipeToDeleteChip] inside
/// the row keeps the swipes that start on it.
class SwipeToDelete extends StatefulWidget {
  const SwipeToDelete({
    super.key,
    required this.canDelete,
    required this.onDelete,
    required this.child,
    this.surface,
    this.ignoreFromStart = 0,
    this.padding = EdgeInsets.zero,
  });

  final bool canDelete;

  /// Removes the row, once it has slid out.
  final VoidCallback onDelete;

  final Widget child;

  /// The opaque surface painted under [child]; defaults to the card color.
  final Color? surface;

  /// Touches starting this close to the row's leading edge (over a drag
  /// handle, say) never swipe it.
  final double ignoreFromStart;

  /// Space around the row (the gap to the next one, say) that folds away
  /// with it when it is deleted.
  final EdgeInsets padding;

  /// How far an open row slides: the width of its Delete action.
  static const double actionWidth = 88;

  @override
  State<SwipeToDelete> createState() => _SwipeToDeleteState();
}

class _SwipeToDeleteState extends State<SwipeToDelete>
    with TickerProviderStateMixin {
  static const double _slop = 18;
  static const double _actionWidth = SwipeToDelete.actionWidth;

  /// Past the open position on the first swipe, or right of rest: the row
  /// resists and stops short of this.
  static const double _stretch = 28;

  double _offset = 0;
  double _offsetAtDown = 0;
  double _rowWidth = 0;

  /// Resting on its Delete action.
  bool _open = false;
  bool _openAtDown = false;

  /// The second swipe has gone far enough to delete on release.
  bool _armed = false;

  bool _horizontal = false;
  bool _vertical = false;
  bool _deleting = false;
  bool _removed = false;
  Offset? _start;

  late final AnimationController _slider = AnimationController(vsync: this);
  double _animateFrom = 0;
  double _animateTarget = 0;
  Curve _animateCurve = Curves.easeOutCubic;
  VoidCallback? _animateDone;

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  @override
  void initState() {
    super.initState();
    // Listeners live as long as the widget: adding them per animation would
    // let the controller's initial `dismissed` status run a fresh end
    // listener and snap the row to its target instead of animating there.
    _slider
      ..addListener(_onAnimationTick)
      ..addStatusListener(_onAnimationStatus);
  }

  @override
  void dispose() {
    _slider.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SwipeToDelete oldWidget) {
    super.didUpdateWidget(oldWidget);
    // After [onDelete] the parent's rebuild may land the next row in this
    // slot: clear the slid-out state so it renders in place.
    if (_removed) {
      _removed = false;
      _deleting = false;
      setState(_reset);
    } else if (!widget.canDelete && _open) {
      _close();
    }
  }

  void _reset() {
    _offset = 0;
    _open = false;
    _armed = false;
    _horizontal = false;
    _vertical = false;
  }

  /// Gives way less and less past [over], never beyond [_stretch].
  static double _resist(double over) =>
      _stretch * (1 - math.exp(-over / _stretch));

  double get _deleteTravel => math.max(_actionWidth + 64, _rowWidth * 0.5);

  /// Whether [event] went down on a part of the row that swipes on its own
  /// (a [SwipeToDeleteChip]): that swipe is not the row's.
  bool _onNestedSwipe(PointerDownEvent event) {
    final own = context.findRenderObject();
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, event.position, event.viewId);
    // Deepest first: only what sits inside this row counts.
    for (final entry in result.path) {
      final target = entry.target;
      if (identical(target, own)) break;
      if (target is RenderMetaData && identical(target.metaData, _ownSwipe)) {
        return true;
      }
    }
    return false;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_deleting || _start != null) return;
    if (!_open) {
      if (event.localPosition.dx < widget.ignoreFromStart) return;
      if (_onNestedSwipe(event)) return;
    }
    _slider.stop();
    _start = event.position;
    _offsetAtDown = _offset;
    _openAtDown = _open;
    _armed = false;
    _horizontal = false;
    _vertical = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    final start = _start;
    if (start == null || _deleting) return;
    final dx = event.position.dx - start.dx;
    final dy = event.position.dy - start.dy;
    if (!_horizontal && !_vertical) {
      // Wait for a clear direction: a vertical-leaning finger belongs to the
      // page scroll and is never stolen by the swipe.
      if (dy.abs() > _slop && dy.abs() > dx.abs()) {
        _vertical = true;
        return;
      }
      if (dx.abs() < _slop) return;
      _horizontal = true;
    }
    if (_vertical) return;

    final raw = _offsetAtDown + dx;
    final double next;
    if (raw > 0) {
      next = _resist(raw);
    } else if (!widget.canDelete) {
      next = -_resist(-raw);
    } else if (!_openAtDown) {
      // The first swipe opens the row and no further: one swipe alone can
      // never delete.
      next = raw >= -_actionWidth
          ? raw
          : -_actionWidth - _resist(-_actionWidth - raw);
    } else {
      next = math.max(raw, -_rowWidth);
    }
    final armed = _openAtDown && widget.canDelete && -next >= _deleteTravel;
    if (armed && !_armed) {
      HapticFeedback.mediumImpact();
      _shake.forward(from: 0);
    }
    setState(() {
      _offset = next;
      _armed = armed;
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    final swiped = _horizontal && !_vertical;
    _start = null;
    if (_deleting || !swiped) return;
    if (!widget.canDelete) {
      _close();
    } else if (_armed) {
      _delete();
    } else if (-_offset >= _actionWidth * (_openAtDown ? 0.6 : 0.5)) {
      _openUp();
    } else {
      _close();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    final swiped = _horizontal && !_vertical;
    _start = null;
    if (_deleting || !swiped) return;
    _open ? _openUp() : _close();
  }

  void _openUp() {
    if (!_open) HapticFeedback.selectionClick();
    _open = true;
    _armed = false;
    _animateTo(-_actionWidth);
  }

  void _close() {
    _open = false;
    _armed = false;
    _animateTo(0);
  }

  void _delete() {
    if (_deleting || !widget.canDelete) return;
    _deleting = true;
    _open = false;
    _animateTo(
      -math.max(_rowWidth, -_offset),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInCubic,
      done: widget.onDelete,
    );
  }

  void _onAnimationTick() {
    if (!mounted) return;
    final t = _animateCurve.transform(_slider.value);
    setState(
      () => _offset = _animateFrom + (_animateTarget - _animateFrom) * t,
    );
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final done = _animateDone;
    _animateDone = null;
    if (!mounted) return;
    setState(() {
      _offset = _animateTarget;
      _removed = done != null;
    });
    done?.call();
  }

  void _animateTo(
    double target, {
    Duration duration = const Duration(milliseconds: 240),
    Curve curve = Curves.easeOutCubic,
    VoidCallback? done,
  }) {
    _animateFrom = _offset;
    _animateTarget = target;
    _animateCurve = curve;
    _animateDone = done;
    _slider
      ..duration = duration
      ..stop()
      ..value = 0
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return LayoutBuilder(
      builder: (context, constraints) {
        _rowWidth = constraints.maxWidth;
        final revealed = -_offset;
        // Slid out: the row folds up and fades as it goes, so the gap closes
        // with the exit instead of snapping shut on the parent's rebuild.
        final folding = _deleting ? _slider.value : 0.0;
        final resting = _open && _start == null && !_deleting;
        return TapRegion(
          onTapOutside: (_) {
            if (_open && !_deleting && _start == null) setState(_close);
          },
          child: Semantics(
            customSemanticsActions: widget.canDelete
                ? {const CustomSemanticsAction(label: 'Delete'): _delete}
                : null,
            child: Listener(
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              behavior: HitTestBehavior.deferToChild,
              child: ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: 1 - folding,
                  // Align loosens the width: keep the row full width.
                  child: SizedBox(
                    width: _rowWidth,
                    child: Opacity(
                      opacity: 1 - folding,
                      child: Padding(
                        padding: widget.padding,
                        child: Stack(
                          fit: StackFit.passthrough,
                          children: <Widget>[
                            if (widget.canDelete && revealed > 0)
                              Positioned(
                                right: 0,
                                top: 0,
                                bottom: 0,
                                width: math.max(revealed, _actionWidth),
                                child: _DeleteAction(
                                  revealed: revealed,
                                  armed: _armed,
                                  shake: _shake,
                                  onPress: _delete,
                                ),
                              ),
                            Transform.translate(
                              offset: Offset(_offset, 0),
                              child: ColoredBox(
                                color: widget.surface ?? theme.colors.card,
                                child: Stack(
                                  fit: StackFit.passthrough,
                                  children: <Widget>[
                                    widget.child,
                                    // Open, the row itself only closes again.
                                    if (resting)
                                      Positioned.fill(
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () => setState(_close),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Marks, for the hit test, a part of a row that swipes on its own.
const Object _ownSwipe = Object();

/// The red action an open row rests on: Delete, then "Release to delete"
/// once a second swipe has gone far enough.
class _DeleteAction extends StatelessWidget {
  const _DeleteAction({
    required this.revealed,
    required this.armed,
    required this.shake,
    required this.onPress,
  });

  final double revealed;
  final bool armed;
  final AnimationController shake;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final foreground = theme.colors.destructiveForeground;
    // Content fades in as the action comes into view.
    final shown = ((revealed - 24) / 40).clamp(0.0, 1.0);
    return Semantics(
      button: true,
      label: 'Delete',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPress,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colors.destructive,
            borderRadius: theme.style.borderRadius.md,
          ),
          child: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: revealed,
              child: Opacity(
                opacity: shown,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          AnimatedBuilder(
                            animation: shake,
                            builder: (context, child) {
                              final t = shake.value;
                              final angle =
                                  math.sin(t * 2 * math.pi * 2) *
                                  0.12 *
                                  (1 - t);
                              return Transform.rotate(
                                angle: angle,
                                child: child,
                              );
                            },
                            child: Icon(
                              FLucideIcons.trash2,
                              size: 18,
                              color: foreground,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            armed ? 'Release to delete' : 'Delete',
                            style: theme.typography.body.xs.copyWith(
                              color: foreground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [SwipeToDelete] for a small tile in a grid, which has no room to slide
/// open: the first swipe left turns it into a red trash tile, a second swipe
/// left deletes it. A tap on the trash tile, a tap anywhere else or a swipe
/// right turns it back.
class SwipeToDeleteChip extends StatefulWidget {
  const SwipeToDeleteChip({
    super.key,
    required this.canDelete,
    required this.onDelete,
    required this.child,
    this.radius = 8,
  });

  final bool canDelete;

  /// Removes the tile, once it has shrunk away.
  final VoidCallback onDelete;

  final Widget child;
  final double radius;

  @override
  State<SwipeToDeleteChip> createState() => _SwipeToDeleteChipState();
}

class _SwipeToDeleteChipState extends State<SwipeToDeleteChip>
    with TickerProviderStateMixin {
  /// Finger travel that counts as a swipe.
  static const double _trigger = 28;

  double _drag = 0;
  bool _armed = false;
  bool _deleting = false;
  bool _removed = false;

  late final AnimationController _out = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  )..addStatusListener(_onOut);

  late final AnimationController _back = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..addListener(() => setState(() => _drag = _dragAtRelease * _back.value));
  double _dragAtRelease = 0;

  @override
  void dispose() {
    _out.dispose();
    _back.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SwipeToDeleteChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    // After [onDelete] the next tile may land in this slot: show it whole.
    if (_removed) {
      _removed = false;
      _deleting = false;
      _armed = false;
      _drag = 0;
      _out.value = 0;
    } else if (!widget.canDelete && _armed) {
      _armed = false;
    }
  }

  void _onOut(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    _removed = true;
    widget.onDelete();
  }

  void _onUpdate(DragUpdateDetails details) {
    if (_deleting) return;
    _back.stop();
    setState(() => _drag += details.primaryDelta ?? 0);
  }

  void _onEnd([DragEndDetails? _]) {
    if (_deleting) return;
    final drag = _drag;
    if (widget.canDelete && drag <= -_trigger) {
      if (_armed) {
        HapticFeedback.mediumImpact();
        _deleting = true;
        _out.forward(from: 0);
      } else {
        HapticFeedback.selectionClick();
        _armed = true;
      }
    } else if (drag >= _trigger) {
      _armed = false;
    }
    // Spring back onto the grid, armed or not.
    _dragAtRelease = drag;
    _back.reverse(from: 1);
  }

  void _disarm() {
    if (_armed && !_deleting) setState(() => _armed = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    // Follows the finger a little, then resists.
    final follow = 10 * (1 - math.exp(-_drag.abs() / 24)) * _drag.sign;
    final redness = _armed
        ? 1.0
        : widget.canDelete
        ? (-_drag / _trigger).clamp(0.0, 1.0) * 0.6
        : 0.0;
    return TapRegion(
      onTapOutside: (_) => _disarm(),
      // Inside a [SwipeToDelete] row, a swipe starting here stays the
      // tile's: the row never moves with it.
      child: MetaData(
        metaData: _ownSwipe,
        child: Semantics(
          customSemanticsActions: widget.canDelete
              ? {const CustomSemanticsAction(label: 'Delete'): widget.onDelete}
              : null,
          child: GestureDetector(
            onHorizontalDragUpdate: _onUpdate,
            onHorizontalDragEnd: _onEnd,
            onHorizontalDragCancel: _onEnd,
            child: AnimatedBuilder(
              animation: _out,
              builder: (context, child) {
                final t = Curves.easeInCubic.transform(_out.value);
                return Opacity(
                  opacity: 1 - t,
                  child: Transform.scale(scale: 1 - 0.4 * t, child: child),
                );
              },
              child: Transform.translate(
                offset: Offset(follow, 0),
                child: Stack(
                  fit: StackFit.passthrough,
                  children: <Widget>[
                    widget.child,
                    if (redness > 0)
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: !_armed,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _disarm,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: theme.colors.destructive.withValues(
                                  alpha: redness,
                                ),
                                borderRadius: BorderRadius.circular(
                                  widget.radius,
                                ),
                              ),
                              child: _armed
                                  ? Icon(
                                      FLucideIcons.trash2,
                                      size: 18,
                                      color: theme.colors.destructiveForeground,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
