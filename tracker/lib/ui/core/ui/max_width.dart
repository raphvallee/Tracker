import 'package:flutter/material.dart';

class MaxWidth extends StatelessWidget {
  const MaxWidth({super.key, this.max = defaultMaxWidth, required this.child});

  static const double defaultMaxWidth = 720;

  final double max;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: max),
        child: child,
      ),
    );
  }
}
