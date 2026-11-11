import 'package:flutter/widgets.dart';

/// Slides its child up from the bottom edge when it first shows; [hide]
/// slides it back down. Instant when the platform asks for less motion. The
/// number keypads ride on it.
class SlideUpPanel extends StatefulWidget {
  const SlideUpPanel({super.key, required this.child});

  final Widget child;

  @override
  State<SlideUpPanel> createState() => SlideUpPanelState();
}

class SlideUpPanelState extends State<SlideUpPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    reverseDuration: const Duration(milliseconds: 170),
  );

  late final Animation<Offset> _offset = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  ).drive(Tween(begin: const Offset(0, 1), end: Offset.zero));

  bool get _instant => MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isDismissed && !_controller.isAnimating) show();
  }

  void show() {
    if (_instant) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  Future<void> hide() {
    if (_instant) {
      _controller.value = 0;
      return Future<void>.value();
    }
    return _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SlideTransition(position: _offset, child: widget.child);
}
