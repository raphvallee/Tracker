import 'package:flutter/widgets.dart';

/// A dashed outline along a rounded rectangle, drawn inside its bounds so it
/// never changes the size of what it outlines.
class DashedOutline extends CustomPainter {
  const DashedOutline({
    required this.color,
    this.radius = 8,
    this.width = 1,
    this.dash = 4,
    this.gap = 3,
  });

  final Color color;
  final double radius;
  final double width;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(width / 2),
      );
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(DashedOutline oldDelegate) =>
      color != oldDelegate.color ||
      radius != oldDelegate.radius ||
      width != oldDelegate.width ||
      dash != oldDelegate.dash ||
      gap != oldDelegate.gap;
}
