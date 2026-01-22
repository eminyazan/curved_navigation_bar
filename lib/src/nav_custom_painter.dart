import 'package:flutter/material.dart';

class NavCustomPainter extends CustomPainter {
  late double loc;
  late double s;
  Color color;
  TextDirection textDirection;
  double flatten; // New variable: 0.0 = Curved, 1.0 = Flat

  NavCustomPainter(
      double startingLoc, int itemsLength, this.color, this.textDirection, this.flatten) {
    final span = 1.0 / itemsLength;
    s = 0.2;
    double l = startingLoc + (span - s) / 2;
    loc = textDirection == TextDirection.rtl ? 0.8 - l : l;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // We scale the "depth" of the curve by (1 - flatten)
    // If flatten is 1.0, these become 0.0, creating a straight line.
    double curveHeight = size.height * 0.60 * (1 - flatten);
    double topHeight = size.height * 0.05 * (1 - flatten);

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo((loc - 0.1) * size.width, 0)
      ..cubicTo(
        (loc + s * 0.20) * size.width,
        topHeight,
        loc * size.width,
        curveHeight,
        (loc + s * 0.50) * size.width,
        curveHeight,
      )
      ..cubicTo(
        (loc + s) * size.width,
        curveHeight,
        (loc + s - s * 0.20) * size.width,
        topHeight,
        (loc + s + 0.1) * size.width,
        0,
      )
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}