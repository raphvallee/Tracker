import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

/// Single-line text that scrolls sideways when it is too long to fit. Swiping
/// works with every pointer, including a mouse on desktop, and no scrollbar is
/// ever shown.
class SwipeableText extends StatelessWidget {
  const SwipeableText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        scrollbars: false,
        dragDevices: PointerDeviceKind.values.toSet(),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(text, style: style, maxLines: 1, softWrap: false),
      ),
    );
  }
}
