import 'dart:async';
import 'dart:ui' show FlutterView;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

const double kKeyboardRevealGap = 40;

/// Height of the on-screen keyboard (the bottom view inset).
///
/// Both shell Scaffolds (`main.dart` FScaffold and the HomePage Scaffold)
/// opt out of `resizeToAvoidBottomInset`, so the shell (app bar, tab bar,
/// backgrounds) never jumps when the keyboard opens; the keyboard simply
/// overlays it. Scrollables that host text fields instead pad their content
/// by [keyboardClearanceOf], so the focused field and trailing actions have
/// the scroll room to move above the keyboard.
double keyboardInsetOf(BuildContext context) =>
    MediaQuery.viewInsetsOf(context).bottom;

double keyboardClearanceOf(BuildContext context) =>
    keyboardInsetOf(context) + kKeyboardRevealGap;

/// Keeps the focused text field [kKeyboardRevealGap] above the on-screen
/// keyboard: on every frame of the keyboard opening, and when focus moves to
/// another field while it is up.
///
/// Flutter reveals a focused caret only until it clears its scrollable's
/// bounds. Since the shell does not resize for the keyboard, those bounds
/// still end at the screen bottom, behind the keyboard, so on its own a field
/// near the bottom stays hidden. This scrolls the field's vertical
/// scrollables just enough to lift it above the keyboard; the padding from
/// [keyboardClearanceOf] gives a page the scroll room. It only ever scrolls
/// further than the field's own reveal (a field with a larger
/// `scrollPadding` keeps its spot), and it rebuilds nothing, so the keyboard
/// animation stays as cheap as the frames around it.
///
/// Wraps the whole app in `MyApp`'s builder, so every route (tab roots,
/// pushed pages, bottom sheets) gets it without each field opting in. A
/// bottom sheet already rides up with the keyboard, so there it does nothing.
class KeyboardReveal extends StatefulWidget {
  const KeyboardReveal({super.key, required this.child});

  final Widget child;

  @override
  State<KeyboardReveal> createState() => _KeyboardRevealState();
}

class _KeyboardRevealState extends State<KeyboardReveal>
    with WidgetsBindingObserver {
  double _inset = 0;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChange);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  FlutterView get _view => View.of(context);

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final view = _view;
    final inset = view.viewInsets.bottom / view.devicePixelRatio;
    final opening = inset > _inset;
    _inset = inset;
    if (opening) _schedule();
  }

  void _onFocusChange() {
    if (_inset > 0) _schedule();
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => _reveal())
      ..ensureVisualUpdate();
  }

  /// Measures right after layout, then scrolls in a microtask: it runs once
  /// every post-frame callback has, including the caret reveal the field
  /// schedules for the same frame, so this one never gets undone.
  void _reveal() {
    _scheduled = false;
    if (!mounted || _inset <= 0) return;
    final field = FocusManager.instance.primaryFocus?.context;
    // Only a text field brings up the keyboard; EditableText holds its
    // FocusNode in a Focus right under it.
    if (field == null ||
        !field.mounted ||
        field.findAncestorStateOfType<EditableTextState>() == null) {
      return;
    }
    final box = field.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final view = _view;
    final keyboardTop =
        view.physicalSize.height / view.devicePixelRatio - _inset;
    final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
    var overlap = bottom + kKeyboardRevealGap - keyboardTop;
    final targets = <(ScrollPosition, double)>[];
    var scrollable = _verticalScrollableAbove(field);
    while (overlap > 0 && scrollable != null) {
      final position = scrollable.position;
      final sign = position.axisDirection == AxisDirection.up ? -1 : 1;
      final target = (position.pixels + sign * overlap).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      overlap -= (target - position.pixels).abs();
      targets.add((position, target));
      scrollable = _verticalScrollableAbove(scrollable.context);
    }
    if (targets.isEmpty) return;
    scheduleMicrotask(() {
      for (final (position, target) in targets) {
        if (!position.hasPixels) continue;
        final further = position.axisDirection == AxisDirection.up
            ? target < position.pixels
            : target > position.pixels;
        if (further) position.jumpTo(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The nearest vertical [Scrollable] above [context], skipping a text
/// field's own horizontal one. Looked up without a dependency: this runs
/// outside any build.
ScrollableState? _verticalScrollableAbove(BuildContext context) {
  var state = context.findAncestorStateOfType<ScrollableState>();
  while (state != null &&
      axisDirectionToAxis(state.axisDirection) != Axis.vertical) {
    state = state.context.findAncestorStateOfType<ScrollableState>();
  }
  return state;
}
