import 'dart:async';

import 'package:flutter/physics.dart' show FrictionSimulation, Tolerance;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/domain/models/number_entry.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/ui/core/themes/accents.dart';
import 'package:tracker/ui/core/ui/accent_button.dart';
import 'package:tracker/ui/core/ui/decimal_input_formatter.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';

/// A key of [NumberKeypad]: a digit or '.', or one of the actions.
enum KeypadKey { digit, backspace, sign, next, hide }

/// Applies one keypad press to [controller]: the typed character replaces the
/// selection (the whole value right after focusing), backspace deletes, sign
/// flips a leading minus. The result passes through the same formatter as
/// typed input.
void applyKeypadKey(
  TextEditingController controller,
  KeypadKey key, {
  String digit = '',
  bool allowNegative = false,
}) {
  final old = controller.value;
  final text = old.text;
  final selection = old.selection.isValid
      ? old.selection
      : TextSelection.collapsed(offset: text.length);
  final start = selection.start;
  final end = selection.end;
  String next;
  int caret;
  switch (key) {
    case KeypadKey.digit:
      next = text.replaceRange(start, end, digit);
      caret = start + digit.length;
    case KeypadKey.backspace:
      if (start != end) {
        next = text.replaceRange(start, end, '');
        caret = start;
      } else if (start > 0) {
        next = text.replaceRange(start - 1, start, '');
        caret = start - 1;
      } else {
        return;
      }
    case KeypadKey.sign:
      if (!allowNegative) return;
      if (text.startsWith('-')) {
        next = text.substring(1);
        caret = (end - 1).clamp(0, next.length);
      } else {
        next = '-$text';
        caret = end + 1;
      }
    case KeypadKey.next:
    case KeypadKey.hide:
      return;
  }
  controller.value = DecimalInputFormatter(allowNegative: allowNegative)
      .formatEditUpdate(
        old,
        TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: caret),
        ),
      );
}

/// The steppers the Keypad and steppers and Keypad and ruler number entries
/// put in [NumberKeypad]: the value they move, how far one step goes and
/// how it reads.
class KeypadSteps {
  const KeypadSteps({
    required this.ruler,
    required this.value,
    required this.step,
    required this.what,
    required this.label,
    required this.onStep,
    this.labelEvery = 5,
    this.last,
  });

  /// A weight's steps: 2.5 kg or 5 lb, a label every 10 kg or 20 lb.
  factory KeypadSteps.weight({
    required bool ruler,
    required double value,
    required WeightUnit unit,
    required ValueChanged<int> onStep,
    double? last,
  }) => KeypadSteps(
    ruler: ruler,
    value: value,
    step: unit == WeightUnit.kilograms ? 2.5 : 5,
    what: 'weight',
    label: (value) => '${formatDecimal(value)} ${unit.symbol}',
    labelEvery: 4,
    last: last,
    onStep: onStep,
  );

  /// A rep count's steps: one rep, a label every 5. [what] names it for
  /// screen readers.
  factory KeypadSteps.reps({
    required bool ruler,
    required double value,
    required ValueChanged<int> onStep,
    String what = 'reps',
    double? last,
  }) => KeypadSteps(
    ruler: ruler,
    value: value,
    step: 1,
    what: what,
    label: (value) => value == 1 ? '1 rep' : '${formatDecimal(value)} reps',
    last: last,
    onStep: onStep,
  );

  /// A ruler on top of the keys; false puts a rocker in their last column.
  final bool ruler;

  /// The value a step starts from: what is typed, else the placeholder.
  final double value;

  /// How far one step goes.
  final double step;

  /// What the value is, for screen readers: "weight", "reps".
  final String what;

  /// A value with its unit: "82.5 kg", "1 rep".
  final String Function(double value) label;

  /// One step up (1) or down (-1).
  final ValueChanged<int> onStep;

  /// The ruler labels a tick every this many steps: 4 for weights (10 kg,
  /// 20 lb), 5 for reps.
  final int labelEvery;

  /// Last time's value, marked on the ruler.
  final double? last;
}

/// The in-app number keypad of the Keypad number entries: big keys, a sign
/// key for assisted machines, Next and a Log button that says what it saves.
/// With [steps] it carries steppers too: a rocker in the key column, or a
/// ruler on top of the keys.
class NumberKeypad extends StatelessWidget {
  const NumberKeypad({
    super.key,
    required this.caption,
    required this.onKey,
    required this.logLabel,
    required this.onLog,
    this.logTrailing,
    this.allowSign = true,
    this.live = true,
    this.steps,
  });

  final String caption;
  final void Function(KeypadKey key, String digit) onKey;
  final String logLabel;

  /// The rating the set logs with, beside [logLabel].
  final String? logTrailing;
  final VoidCallback? onLog;
  final bool allowSign;

  /// The Log button in the live accent, for a running workout; false draws
  /// it in ink, for values that start nothing.
  final bool live;

  /// The steppers in the keypad, for the number entries that have them.
  final KeypadSteps? steps;

  /// Height of the panel without the bottom safe area, so pages can keep
  /// the focused row above it.
  static const double height = 340;

  /// What the ruler adds to [height].
  static const double rulerHeight = 80;

  /// [height] for [entry]'s keypad.
  static double heightOf(NumberEntry entry) =>
      entry == NumberEntry.keypadRuler ? height + rulerHeight : height;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = theme.colors;
    final steps = this.steps;
    final rocker = steps != null && !steps.ruler;
    Widget key(
      String label, {
      KeypadKey kind = KeypadKey.digit,
      IconData? icon,
      bool action = false,
      bool primary = false,
      bool enabled = true,
      String? semantics,
    }) {
      final background = primary
          ? colors.primary
          : action
          ? colors.background
          : colors.muted;
      final foreground = primary
          ? colors.primaryForeground
          : enabled
          ? colors.foreground
          : colors.mutedForeground;
      return FTappable(
        semanticsLabel: semantics ?? label,
        excludeSemantics: true,
        onPress: enabled ? () => onKey(kind, label) : null,
        builder: (context, states, child) => AnimatedOpacity(
          duration: const Duration(milliseconds: 80),
          opacity: states.contains(FTappableVariant.pressed) ? 0.6 : 1,
          child: child,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(10),
            border: action ? Border.all(color: colors.border) : null,
          ),
          alignment: Alignment.center,
          child: icon != null
              ? Icon(icon, color: foreground, size: 20)
              : Text(
                  label,
                  style:
                      (action || primary
                              ? theme.typography.body.sm
                              : theme.typography.body.xl)
                          .copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w600,
                            height: 1,
                          ),
                ),
        ),
      );
    }

    Widget backspace() => key(
      '',
      kind: KeypadKey.backspace,
      icon: FLucideIcons.delete,
      action: true,
      semantics: 'Delete',
    );
    Widget sign() => key(
      '±',
      kind: KeypadKey.sign,
      action: true,
      enabled: allowSign,
      semantics: 'Negative weight',
    );
    Widget next() => key('Next', kind: KeypadKey.next, primary: true);

    const gap = 6.0;
    const keyHeight = 48.0;
    Widget row(List<Widget> keys) => SizedBox(
      height: keyHeight,
      child: Row(
        children: <Widget>[
          for (final (i, k) in keys.indexed) ...[
            if (i > 0) const SizedBox(width: gap),
            Expanded(flex: i == 3 ? 6 : 5, child: k),
          ],
        ],
      ),
    );
    // Two rows of three keys beside one key as tall as both, in the columns
    // of [row].
    Widget block(List<Widget> top, List<Widget> bottom, Widget side) =>
        SizedBox(
          height: keyHeight * 2 + gap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (var i = 0; i < 3; i++) ...[
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(child: top[i]),
                      const SizedBox(height: gap),
                      Expanded(child: bottom[i]),
                    ],
                  ),
                ),
                const SizedBox(width: gap),
              ],
              Expanded(flex: 6, child: side),
            ],
          ),
        );

    final captionText = Text(
      caption,
      style: theme.typography.body.xs.copyWith(color: colors.mutedForeground),
    );
    final keys = rocker
        ? <Widget>[
            row([key('1'), key('2'), key('3'), backspace()]),
            const SizedBox(height: gap),
            block(
              [key('4'), key('5'), key('6')],
              [key('7'), key('8'), key('9')],
              _Rocker(steps: steps),
            ),
            const SizedBox(height: gap),
            row([key('.'), key('0'), sign(), next()]),
          ]
        : <Widget>[
            row([key('1'), key('2'), key('3'), backspace()]),
            const SizedBox(height: gap),
            row([key('4'), key('5'), key('6'), sign()]),
            const SizedBox(height: gap),
            block(
              [key('7'), key('8'), key('9')],
              [
                key('.'),
                key('0'),
                key(
                  '',
                  kind: KeypadKey.hide,
                  icon: FLucideIcons.chevronDown,
                  action: true,
                  semantics: 'Close keypad',
                ),
              ],
              next(),
            ),
          ];

    return GestureDetector(
      // Swiping the panel down closes it, like the phone keyboard.
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 200) onKey(KeypadKey.hide, '');
      },
      child: Container(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          border: Border(top: BorderSide(color: colors.border)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 24,
              offset: Offset(0, -6),
              spreadRadius: -12,
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (rocker)
                  // The rocker takes the close key's place: it moves up here.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 0, 4),
                    child: Row(
                      children: <Widget>[
                        Expanded(child: captionText),
                        FTappable(
                          semanticsLabel: 'Close keypad',
                          excludeSemantics: true,
                          onPress: () => onKey(KeypadKey.hide, ''),
                          child: SizedBox(
                            width: 40,
                            height: 26,
                            child: Icon(
                              FLucideIcons.chevronDown,
                              size: 18,
                              color: colors.foreground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                    child: captionText,
                  ),
                if (steps != null && steps.ruler) ...[
                  _Ruler(steps: steps, live: live),
                  const SizedBox(height: 8),
                ],
                ...keys,
                const SizedBox(height: 10),
                if (live)
                  AccentButton(
                    large: true,
                    prefix: FLucideIcons.check,
                    label: logLabel,
                    trailing: logTrailing,
                    onPress: onLog,
                  )
                else
                  FButton(
                    size: .lg,
                    onPress: onLog,
                    prefix: const Icon(FLucideIcons.check),
                    child: Text(logLabel),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A step control of the keypad: a tap steps once, a hold repeats.
class _StepPress extends StatefulWidget {
  const _StepPress({
    required this.steps,
    required this.direction,
    required this.builder,
  });

  final KeypadSteps steps;
  final int direction;
  final Widget Function(BuildContext context, bool pressed) builder;

  @override
  State<_StepPress> createState() => _StepPressState();
}

class _StepPressState extends State<_StepPress> {
  Timer? _repeat;
  bool _pressed = false;

  // Read at each step: the keypad is rebuilt with the new value.
  void _step() => widget.steps.onStep(widget.direction);

  void _press(bool pressed) {
    if (_pressed != pressed && mounted) setState(() => _pressed = pressed);
  }

  void _stop() {
    _repeat?.cancel();
    _repeat = null;
    _press(false);
  }

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        '${widget.direction > 0 ? 'Increase' : 'Decrease'} '
        '${widget.steps.what}',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _press(true),
      onTapCancel: () => _press(false),
      onTap: () {
        _press(false);
        _step();
      },
      onLongPressStart: (_) {
        _press(true);
        _repeat?.cancel();
        _repeat = Timer.periodic(
          const Duration(milliseconds: 120),
          (_) => _step(),
        );
      },
      onLongPressEnd: (_) => _stop(),
      onLongPressCancel: _stop,
      child: widget.builder(context, _pressed),
    ),
  );
}

/// The Keypad and steppers rocker, as tall as two keys: + on top, - below,
/// the step between. A drag along it steps every 14 px, up adds.
class _Rocker extends StatefulWidget {
  const _Rocker({required this.steps});

  final KeypadSteps steps;

  @override
  State<_Rocker> createState() => _RockerState();
}

class _RockerState extends State<_Rocker> {
  double _scrubbed = 0;

  void _scrub(double dy) {
    _scrubbed += dy;
    while (_scrubbed <= -14) {
      _scrubbed += 14;
      widget.steps.onStep(1);
    }
    while (_scrubbed >= 14) {
      _scrubbed -= 14;
      widget.steps.onStep(-1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = theme.colors;
    final steps = widget.steps;
    Widget half(int direction) => Expanded(
      child: _StepPress(
        steps: steps,
        direction: direction,
        builder: (context, pressed) => ColoredBox(
          color: pressed ? colors.muted : colors.background,
          child: Center(
            child: Icon(
              direction > 0 ? FLucideIcons.plus : FLucideIcons.minus,
              size: 22,
              color: colors.foreground,
            ),
          ),
        ),
      ),
    );
    return GestureDetector(
      onVerticalDragStart: (_) => _scrubbed = 0,
      onVerticalDragUpdate: (details) => _scrub(details.delta.dy),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                half(1),
                Container(height: 1, color: colors.border),
                half(-1),
              ],
            ),
            IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  steps.label(steps.step),
                  maxLines: 1,
                  style: theme.typography.body.xs3.copyWith(
                    color: colors.mutedForeground,
                    fontWeight: FontWeight.w700,
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
}

/// The Keypad and ruler ruler: a tick per step sliding under a fixed index,
/// last time's value marked on it. A drag moves it a step every
/// [_Ruler.spacing] px and a fling carries on; the round buttons at its
/// ends step once.
class _Ruler extends StatefulWidget {
  const _Ruler({required this.steps, required this.live});

  final KeypadSteps steps;
  final bool live;

  static const double spacing = 12;
  static const double height = 72;

  @override
  State<_Ruler> createState() => _RulerState();
}

class _RulerState extends State<_Ruler> with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController.unbounded(
    vsync: this,
  )..addListener(_onMotion);

  /// How far the ruler is dragged past the value, in steps: under half of
  /// one, as every half step crossed steps the value.
  double _carry = 0;
  double _lastMotion = 0;

  /// The motion is easing the carry back to the value's tick, not
  /// carrying a fling.
  bool _settling = false;

  @override
  void didUpdateWidget(covariant _Ruler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.steps.what != widget.steps.what) {
      // Another value: start it on its own tick.
      _motion.stop();
      _settling = false;
      _carry = 0;
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  bool get _instant => MediaQuery.disableAnimationsOf(context);

  void _move(double steps) {
    _carry += steps;
    var moved = false;
    while (_carry >= 0.5) {
      _carry -= 1;
      moved = true;
      widget.steps.onStep(1);
    }
    while (_carry <= -0.5) {
      _carry += 1;
      moved = true;
      widget.steps.onStep(-1);
    }
    if (moved) HapticFeedback.selectionClick();
    setState(() {});
  }

  void _onMotion() {
    final value = _motion.value;
    if (_settling) {
      setState(() => _carry = value);
      return;
    }
    final delta = value - _lastMotion;
    _lastMotion = value;
    _move(delta);
  }

  void _onDragStart(DragStartDetails details) {
    _motion.stop();
    _settling = false;
  }

  void _onDragEnd(DragEndDetails details) {
    // Steps per second, capped so a fling stays within reach of the eye.
    final velocity = (-details.velocity.pixelsPerSecond.dx / _Ruler.spacing)
        .clamp(-80.0, 80.0);
    if (velocity.abs() < 6 || _instant) {
      _settle();
      return;
    }
    _settling = false;
    _lastMotion = 0;
    _motion.value = 0;
    _motion
        .animateWith(
          FrictionSimulation(
            0.02,
            0,
            velocity,
            tolerance: const Tolerance(velocity: 0.5),
          ),
        )
        .whenComplete(_settle);
  }

  /// Eases the ruler onto the value's tick.
  void _settle() {
    if (!mounted) return;
    if (_instant) {
      setState(() => _carry = 0);
      return;
    }
    _settling = true;
    _motion.value = _carry;
    _motion.animateTo(
      0,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = theme.colors;
    final accents = TrackerAccents.of(context);
    final steps = widget.steps;
    final mark = widget.live ? accents.live : colors.foreground;
    final onMark = widget.live ? accents.liveForeground : colors.background;
    final labelStyle = theme.typography.body.xs3.copyWith(
      color: colors.mutedForeground,
      fontWeight: FontWeight.w500,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    Widget end(int direction) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: _StepPress(
        steps: steps,
        direction: direction,
        builder: (context, pressed) => Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: pressed ? colors.muted : colors.background,
            border: Border.all(color: colors.border),
          ),
          child: Icon(
            direction > 0 ? FLucideIcons.plus : FLucideIcons.minus,
            size: 18,
            color: colors.foreground,
          ),
        ),
      ),
    );

    final readout = steps.label(steps.value);
    final ruler = Semantics(
      slider: true,
      label: 'Drag to change the ${steps.what}',
      value: readout,
      increasedValue: steps.label(steps.value + steps.step),
      decreasedValue: steps.label(steps.value - steps.step),
      onIncrease: () => steps.onStep(1),
      onDecrease: () => steps.onStep(-1),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: (details) =>
            _move(-details.delta.dx / _Ruler.spacing),
        onHorizontalDragEnd: _onDragEnd,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: ShaderMask(
                // The ticks fade out towards the ends.
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Color(0x00000000),
                    Color(0xFF000000),
                    Color(0xFF000000),
                    Color(0x00000000),
                  ],
                  stops: [0, 0.22, 0.78, 1],
                ).createShader(bounds),
                child: CustomPaint(
                  painter: _RulerPainter(
                    position: steps.value + _carry * steps.step,
                    step: steps.step,
                    labelEvery: steps.labelEvery,
                    last: steps.last,
                    tick: colors.mutedForeground,
                    lastTick: colors.foreground,
                    labelStyle: labelStyle,
                    lastStyle: labelStyle.copyWith(
                      color: colors.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 22,
              bottom: 18,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 2,
                  decoration: BoxDecoration(
                    color: mark,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: mark,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      readout,
                      maxLines: 1,
                      style: theme.typography.body.xs.copyWith(
                        color: onMark,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return SizedBox(
      height: _Ruler.height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          end(-1),
          const SizedBox(width: 6),
          Expanded(child: ruler),
          const SizedBox(width: 6),
          end(1),
        ],
      ),
    );
  }
}

/// The ruler's ticks around [position], the value under its centre: long
/// and labelled every [labelEvery] steps, half as long halfway between, and
/// last time's value in ink.
class _RulerPainter extends CustomPainter {
  _RulerPainter({
    required this.position,
    required this.step,
    required this.labelEvery,
    required this.last,
    required this.tick,
    required this.lastTick,
    required this.labelStyle,
    required this.lastStyle,
  });

  final double position;
  final double step;
  final int labelEvery;
  final double? last;
  final Color tick;
  final Color lastTick;
  final TextStyle labelStyle;
  final TextStyle lastStyle;

  /// Where the ticks stand.
  static const double baseline = 52;

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = _Ruler.spacing;
    final centre = size.width / 2;
    double xOf(double value) => centre + (value - position) / step * spacing;

    void label(String text, double x, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      painter.paint(canvas, Offset(x - painter.width / 2, baseline + 5));
      painter.dispose();
    }

    final minor = Paint()
      ..color = tick.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = tick
      ..strokeWidth = 1.5;
    final half = labelEvery.isEven ? labelEvery ~/ 2 : null;
    final lastX = last == null ? null : xOf(last!);
    final reach = centre / spacing + 1;
    final first = (position / step - reach).floor();
    final end = (position / step + reach).ceil();
    for (var i = first; i <= end; i++) {
      final x = xOf(i * step);
      final long = i % labelEvery == 0;
      final length = long
          ? 20.0
          : half != null && i % half == 0
          ? 14.0
          : 9.0;
      canvas.drawLine(
        Offset(x, baseline - length),
        Offset(x, baseline),
        long ? major : minor,
      );
      // Last time's label wins the room around it.
      if (long && (lastX == null || (x - lastX).abs() > 30)) {
        label(formatDecimal(i * step), x, labelStyle);
      }
    }
    if (lastX != null && lastX > -40 && lastX < size.width + 40) {
      canvas.drawLine(
        Offset(lastX, baseline - 26),
        Offset(lastX, baseline),
        Paint()
          ..color = lastTick
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
      label('last ${formatDecimal(last!)}', lastX, lastStyle);
    }
  }

  @override
  bool shouldRepaint(_RulerPainter oldDelegate) =>
      oldDelegate.position != position ||
      oldDelegate.step != step ||
      oldDelegate.labelEvery != labelEvery ||
      oldDelegate.last != last ||
      oldDelegate.tick != tick ||
      oldDelegate.lastTick != lastTick ||
      oldDelegate.labelStyle != labelStyle ||
      oldDelegate.lastStyle != lastStyle;
}

/// The bar the Phone keyboard number entry shows on top of the keyboard,
/// which covers the page's Log button: sign, Next and Log.
class KeyboardToolbar extends StatelessWidget {
  const KeyboardToolbar({
    super.key,
    required this.onSign,
    required this.onNext,
    required this.logLabel,
    required this.onLog,
    this.logTrailing,
    this.live = true,
  });

  final VoidCallback? onSign;
  final VoidCallback onNext;
  final String logLabel;

  /// The rating the set logs with, beside [logLabel].
  final String? logTrailing;
  final VoidCallback? onLog;

  /// The Log button in the live accent; false draws it in ink.
  final bool live;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: <Widget>[
          FButton(
            variant: .outline,
            size: .sm,
            mainAxisSize: .min,
            onPress: onSign,
            semanticsTooltip: 'Negative weight',
            child: const Text('±'),
          ),
          const Spacer(),
          FButton(
            variant: .outline,
            size: .sm,
            mainAxisSize: .min,
            onPress: onNext,
            child: const Text('Next'),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 3,
            child: live
                ? AccentButton(
                    prefix: FLucideIcons.check,
                    label: logLabel,
                    trailing: logTrailing,
                    onPress: onLog,
                  )
                : FButton(
                    onPress: onLog,
                    prefix: const Icon(FLucideIcons.check),
                    child: Text(logLabel),
                  ),
          ),
        ],
      ),
    );
  }
}
