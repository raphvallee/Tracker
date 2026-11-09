import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:forui/forui.dart';

/// A hand-rolled variant of [Dismissible] for rows whose children - text
/// fields - win the horizontal drag in the gesture arena themselves, keeping
/// [Dismissible] from ever seeing the gesture. It bypasses the arena entirely
/// by working off raw [Listener] pointer events: the row follows the finger
/// leftwards (end-to-start) through a rubber-band resistance that tightens on
/// the approach to the delete gate (63.5% of the row's width). Pushing past
/// the gate arms the delete: the row snaps to the final deletion position, a
/// haptic fires, the trash icon shakes and the Delete label slides in.
/// Retreating below the gate disarms again and the row springs back onto the
/// finger. Releasing armed asks [onConfirm] whether the row actually goes;
/// [onConfirmed] removes it after the slide-out animation.
class SwipeToDelete extends StatefulWidget {
  const SwipeToDelete({
    super.key,
    required this.canDelete,
    required this.onConfirm,
    required this.onConfirmed,
    required this.child,
    this.surface,
  });

  final bool canDelete;

  final Future<bool> Function() onConfirm;

  final VoidCallback onConfirmed;

  final Widget child;

  /// The opaque surface painted under [child]; defaults to the card color.
  final Color? surface;

  @override
  State<SwipeToDelete> createState() => _SwipeToDeleteState();
}

class _SwipeToDeleteState extends State<SwipeToDelete>
    with TickerProviderStateMixin {
  static const double _slop = 18;

  static const double _rubberBandZone = 0.75;

  static const double _dismissFraction = 0.635;

  static const double _rubberBandTail = 0.4;

  static const double _gateStiffening = 0.5;

  static const double _rubberBandNeck = 24;
  static const double _rubberBandMax = 56;
  static const double _rubberBandRange = 120;

  double _offset = 0;
  double _rowWidth = 0;

  double _fingerDistance = 0;

  bool _armed = false;
  bool _horizontal = false;
  bool _vertical = false;
  bool _busy = false;

  bool _dismissing = false;

  bool _removed = false;
  Offset? _start;

  late final AnimationController _slider = AnimationController(
    vsync: this,
    duration: _springBackDuration,
  );

  double _animateFrom = 0;

  double _animateTarget = 0;

  Curve _animateCurve = Curves.easeOutCubic;

  VoidCallback? _animateDone;

  static const Duration _springBackDuration = Duration(milliseconds: 220);
  static const Duration _slideOutDuration = Duration(milliseconds: 160);

  static const Duration _shakeDuration = Duration(milliseconds: 350);

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: _shakeDuration,
  );

  @override
  void initState() {
    super.initState();
    // Listeners live for the whole widget lifetime: adding them per animation
    // would let the controller's initial `dismissed` status (reported when it
    // is rewound to 0) run a freshly added end listener and snap the row to
    // its target instead of animating there.
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
    // After [onConfirmed] the parent's rebuild lands the shifted content in
    // this slot; clear the stale off-screen transform now, so the new row
    // renders in place. Rebuilds during the slide-out itself are ignored:
    // stopping the animation there would cancel the removal.
    if (_removed) {
      _removed = false;
      _busy = false;
      _dismissing = false;
      setState(_resetOffset);
    }
  }

  void _resetOffset() {
    _offset = 0;
    _fingerDistance = 0;
    _armed = false;
    _horizontal = false;
    _vertical = false;
  }

  double _rubberBand(double dx) {
    final travel = dx.abs();
    if (travel <= _rubberBandNeck) return dx;
    final overshoot = travel - _rubberBandNeck;
    final resisted =
        _rubberBandNeck +
        (_rubberBandMax - _rubberBandNeck) *
            math.sqrt(overshoot / (overshoot + _rubberBandRange));
    return dx.isNegative ? -resisted : resisted;
  }

  double _deletableOffset(double dx) {
    if (dx == 0) return 0;
    final distance = dx.abs();
    final gate = _rowWidth * _dismissFraction;
    final bandEnd = gate * _rubberBandZone;
    if (bandEnd <= 0) return dx;
    final atBandEnd = bandEnd * (1 + _rubberBandTail) / 2;
    final zone = gate - bandEnd;
    final double travelled;
    if (distance <= bandEnd) {
      travelled =
          distance -
          (1 - _rubberBandTail) * distance * distance / (2 * bandEnd);
    } else if (distance <= gate) {
      final u = distance - bandEnd;
      travelled = atBandEnd + u - _gateStiffening * u * u / (2 * zone);
    } else {
      final atGate = atBandEnd + zone * (1 - _gateStiffening / 2);
      travelled = atGate + (1 - _gateStiffening) * (distance - gate);
    }
    return dx.isNegative ? -travelled : travelled;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_busy) return;
    if (_start != null) return;
    _slider.stop();
    _start = event.position;
    _fingerDistance = 0;
    _armed = false;
    _horizontal = false;
    _vertical = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    final start = _start;
    if (start == null || _busy) return;
    final dx = event.position.dx - start.dx;
    final dy = event.position.dy - start.dy;

    if (!_horizontal && !_vertical) {
      // Wait for a clear direction: a vertical-leaning finger belongs to the
      // page scroll and must never be stolen by the swipe.
      if (dy.abs() > _slop && dy.abs() > dx.abs()) {
        _vertical = true;
        return;
      }
      if (dx.abs() < _slop) return;
      _horizontal = true;
    }
    if (_vertical) return;

    // End-to-start only: the row travels leftwards; overshoot to the right
    // rubber-bands at its rest position. Slow drags past the full row width
    // are clamped so the row never flips around. A row that cannot be
    // deleted never leaves its rest area: it only follows the finger through
    // the sqrt rubber band, with no delete background behind it. A deletable
    // row lags the finger for the first part of the swipe, then tracks it.
    // The finger distance itself is not clamped - it is what the delete rule
    // and the debug log measure, so dragging past the row reads over 100%.
    _fingerDistance = dx < 0 ? -dx : 0;
    final armed = widget.canDelete && _fingerDistance >= _dismissTarget;
    final wasArmed = _armed;
    _armed = armed;
    final travel = dx.clamp(-_rowWidth, 0).toDouble();
    setState(() {
      _offset = !widget.canDelete
          ? _rubberBand(travel)
          : _deletableOffset(travel);
    });
    if (armed && !wasArmed) HapticFeedback.mediumImpact();
    _logSwipeProgress();
  }

  double get _dismissTarget => _rowWidth * _dismissFraction;

  void _logSwipeProgress() {
    if (!kDebugMode || _rowWidth <= 0) return;
    final percent = _fingerDistance / _rowWidth * 100;
    debugPrint('Set row swipe: ${percent.toStringAsFixed(1)}%');
  }

  Future<void> _onPointerUp(PointerUpEvent event) async {
    final horizontal = _horizontal;
    final swiped = _fingerDistance;
    _start = null;
    _fingerDistance = 0;
    if (_busy || _vertical || !horizontal) return;

    final dismisses =
        widget.canDelete && swiped >= _rowWidth * _dismissFraction;
    if (!dismisses) {
      _animateTo(0);
      return;
    }

    _busy = true;
    final confirmed = await widget.onConfirm();
    if (!mounted) return;
    if (!confirmed) {
      _busy = false;
      _dismissing = false;
      _animateTo(0);
      return;
    }
    _dismissing = true;
    _animateTo(
      -_rowWidth,
      duration: _slideOutDuration,
      curve: Curves.easeInCubic,
      done: widget.onConfirmed,
    );
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _start = null;
    _fingerDistance = 0;
    if (_busy || _vertical || !_horizontal) return;
    _animateTo(0);
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
    Duration duration = _springBackDuration,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        _rowWidth = constraints.maxWidth;
        final threshold = (_rowWidth * _dismissFraction).clamp(0.0, _rowWidth);
        final dismissProgress = _dismissing ? _slider.value : 0.0;
        return Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          behavior: HitTestBehavior.deferToChild,
          child: Stack(
            fit: StackFit.passthrough,
            children: <Widget>[
              if (widget.canDelete)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: threshold,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.theme.colors.destructive,
                      borderRadius: context.theme.style.borderRadius.md,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: _ArmedIndicator(visible: _armed, shake: _shake),
                      ),
                    ),
                  ),
                ),
              // The translated row paints on top of the background; Stack's
              // default clipping keeps it from bleeding over neighbouring
              // rows while it slides. The row itself is opaque: its own
              // paddings (top spacing), the gap between the two fields and
              // the fields' rounded corners are otherwise transparent and
              // would let the red delete background bleed through at rest.
              // While a confirmed swipe slides the row out, collapse its height
              // and fade it so the gap closes during the exit instead of
              // snapping shut when the parent rebuilds.
              ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: 1 - dismissProgress,
                  child: Opacity(
                    opacity: 1 - dismissProgress,
                    child: Transform.translate(
                      offset: Offset(_offset, 0),
                      child: ColoredBox(
                        color: widget.surface ?? context.theme.colors.card,
                        child: widget.child,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ArmedIndicator extends StatelessWidget {
  const _ArmedIndicator({required this.visible, required this.shake});

  static const Duration _labelDuration = Duration(milliseconds: 150);

  final bool visible;

  final AnimationController shake;

  @override
  Widget build(BuildContext context) {
    final foreground = context.theme.colors.destructiveForeground;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AnimatedSize(
          duration: _labelDuration,
          curve: Curves.easeOutCubic,
          alignment: AlignmentDirectional.centerEnd,
          child: visible
              ? Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: Text(
                    'Delete',
                    style: context.theme.typography.body.sm.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        AnimatedBuilder(
          animation: shake,
          builder: (context, child) {
            final t = shake.value;
            final angle = math.sin(t * 2 * math.pi * 2) * 0.12 * (1 - t);
            return Transform.rotate(angle: angle, child: child);
          },
          child: Icon(FLucideIcons.trash2, color: foreground),
        ),
      ],
    );
  }
}
