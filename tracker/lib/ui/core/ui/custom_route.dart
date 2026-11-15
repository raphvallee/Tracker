import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/ui/core/ui/motion.dart';

Future<T?> pushTo<T>(BuildContext context, Widget destination) {
  final Color backgroundColor = context.theme.colors.background;
  return Navigator.of(context).push<T>(
    _createRoute(backgroundColor, destination, Motion.reduced(context)),
  );
}

/// Replaces the current page with [destination], sliding in like [pushTo].
Future<T?> replaceWith<T>(BuildContext context, Widget destination) {
  final Color backgroundColor = context.theme.colors.background;
  return Navigator.of(context).pushReplacement<T, Object?>(
    _createRoute(backgroundColor, destination, Motion.reduced(context)),
  );
}

/// The sliding route [pushTo] uses, for pushing on another navigator.
Route<T> slideRoute<T>(BuildContext context, Widget destination) =>
    _createRoute(
      context.theme.colors.background,
      destination,
      Motion.reduced(context),
    );

/// A page slides in from the side like a panel (M11): it eases into place
/// over 240 ms and leaves faster, over 170 ms. With reduced motion it is
/// there at once.
Route<T> _createRoute<T>(
  Color backgroundColor,
  Widget destination,
  bool reduced,
) {
  return PageRouteBuilder<T>(
    transitionDuration: reduced ? Duration.zero : Motion.panelIn,
    reverseTransitionDuration: reduced ? Duration.zero : Motion.panelOut,
    barrierColor: backgroundColor,
    // Opaque routes ignore the barrier color, so the destination must paint
    // the background itself or the body renders black.
    pageBuilder: (context, animation, secondaryAnimation) =>
        ColoredBox(color: backgroundColor, child: destination),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slide = Tween(begin: const Offset(1, 0), end: Offset.zero).animate(
        CurvedAnimation(
          parent: animation,
          curve: Motion.enter,
          reverseCurve: Motion.exit,
        ),
      );
      return SlideTransition(position: slide, child: child);
    },
  );
}
