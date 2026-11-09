import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

Future<T?> pushTo<T>(BuildContext context, Widget destination) {
  final Color backgroundColor = context.theme.colors.background;
  return Navigator.of(context)
      .push<T>(_createRoute(backgroundColor, destination));
}

/// Replaces the current page with [destination], sliding in like [pushTo].
Future<T?> replaceWith<T>(BuildContext context, Widget destination) {
  final Color backgroundColor = context.theme.colors.background;
  return Navigator.of(context)
      .pushReplacement<T, Object?>(_createRoute(backgroundColor, destination));
}

/// The sliding route [pushTo] uses, for pushing on another navigator.
Route<T> slideRoute<T>(BuildContext context, Widget destination) =>
    _createRoute(context.theme.colors.background, destination);

Route<T> _createRoute<T>(Color backgroundColor, Widget destination) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 250),
    barrierColor: backgroundColor,
    // Opaque routes ignore the barrier color, so the destination must paint
    // the background itself or the body renders black.
    pageBuilder: (context, animation, secondaryAnimation) =>
        ColoredBox(color: backgroundColor, child: destination),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0);
      const end = Offset.zero;
      const curve = Curves.ease;
      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}
