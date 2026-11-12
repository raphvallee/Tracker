import 'dart:ui' show PointerDeviceKind;

import 'package:material_ui/material_ui.dart';

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
