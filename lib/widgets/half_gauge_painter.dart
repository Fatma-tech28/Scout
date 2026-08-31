import 'dart:math';
import 'package:flutter/material.dart';

class HalfGaugePainter extends CustomPainter {
  final double value; // 0..1
  final Color trackColor;
  final List<Color> valueGradient;
  final double strokeWidth;

  HalfGaugePainter({
    required this.value,
    required this.trackColor,
    required this.valueGradient,
    this.strokeWidth = 16,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final clamped = value.clamp(0.0, 1.0);
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.width - strokeWidth,
    );
    final center = rect.center;
    final radius = rect.width / 2;
    final sweep = pi * clamped;

    if (clamped > 0.01) {
      final glowPaint = Paint()
        ..color = valueGradient.last.withValues(alpha: 0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 12
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
      canvas.drawArc(rect, pi, sweep, false, glowPaint);
    }

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, pi, pi, false, track);

    final tickPaint = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i <= 10; i++) {
      final angle = pi + (pi * i / 10);
      final isMajor = i % 5 == 0;
      final outer = radius + strokeWidth / 2 + 3;
      final inner = outer - (isMajor ? 7 : 3.5);
      final p1 = Offset(center.dx + inner * cos(angle), center.dy + inner * sin(angle));
      final p2 = Offset(center.dx + outer * cos(angle), center.dy + outer * sin(angle));
      canvas.drawLine(
        p1,
        p2,
        tickPaint..color = Colors.white.withValues(alpha: isMajor ? 0.9 : 0.55),
      );
    }

    final valuePaint = Paint()
      ..shader = SweepGradient(
        startAngle: pi,
        endAngle: 2 * pi,
        colors: valueGradient,
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, pi, sweep, false, valuePaint);

    final knobAngle = pi + sweep;
    final knobCenter = Offset(
      center.dx + radius * cos(knobAngle),
      center.dy + radius * sin(knobAngle),
    );
    final knobColor = valueGradient.last;
    canvas.drawCircle(
      knobCenter,
      strokeWidth * 0.62,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(knobCenter, strokeWidth * 0.52, Paint()..color = Colors.white);
    canvas.drawCircle(knobCenter, strokeWidth * 0.34, Paint()..color = knobColor);
  }

  @override
  bool shouldRepaint(covariant HalfGaugePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.valueGradient != valueGradient ||
        oldDelegate.trackColor != trackColor;
  }
}
