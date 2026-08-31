import 'dart:math';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BatteryVisual extends StatefulWidget {
  final double percent;
  final bool charging;
  final double width;
  final double height;

  const BatteryVisual({
    super.key,
    required this.percent,
    required this.charging,
    this.width = 150,
    this.height = 300,
  });

  @override
  State<BatteryVisual> createState() => _BatteryVisualState();
}

class _BatteryVisualState extends State<BatteryVisual> with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  Color get _levelColor {
    if (widget.percent <= 20) return AppColors.danger;
    if (widget.percent <= 45) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: widget.percent.clamp(0, 100).toDouble()),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, animatedPercent, _) {
          return AnimatedBuilder(
            animation: _wave,
            builder: (context, __) {
              return CustomPaint(
                painter: _BatteryPainter(
                  percent: animatedPercent,
                  color: _levelColor,
                  wavePhase: _wave.value * 2 * pi,
                  charging: widget.charging,
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.charging)
                          const Icon(Icons.bolt_rounded, color: Colors.white, size: 34)
                        else
                          const SizedBox(height: 4),
                        Text(
                          '${animatedPercent.round()}%',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: animatedPercent > 45 ? Colors.white : AppColors.textPrimary,
                            shadows: const [Shadow(color: Colors.black26, blurRadius: 4)],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _BatteryPainter extends CustomPainter {
  final double percent;
  final Color color;
  final double wavePhase;
  final bool charging;

  _BatteryPainter({
    required this.percent,
    required this.color,
    required this.wavePhase,
    required this.charging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final capWidth = size.width * 0.28;
    final capHeight = size.height * 0.035;
    final bodyTop = capHeight + 4;
    final bodyRect = Rect.fromLTWH(0, bodyTop, size.width, size.height - bodyTop);
    final bodyRRect = RRect.fromRectAndRadius(bodyRect, Radius.circular(size.width * 0.16));

    final capRect = Rect.fromLTWH((size.width - capWidth) / 2, 0, capWidth, capHeight + 6);
    final capRRect = RRect.fromRectAndCorners(
      capRect,
      topLeft: Radius.circular(size.width * 0.05),
      topRight: Radius.circular(size.width * 0.05),
    );
    canvas.drawRRect(capRRect, Paint()..color = AppColors.surfaceOutline);

    canvas.drawRRect(bodyRRect, Paint()..color = AppColors.surface);
    canvas.drawRRect(
      bodyRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.surfaceOutline,
    );

    canvas.save();
    canvas.clipRRect(bodyRRect);

    final fillRatio = (percent / 100).clamp(0.0, 1.0);
    final fillHeight = bodyRect.height * fillRatio;
    final fillTop = bodyRect.bottom - fillHeight;

    final wavePath = Path();
    const waveAmplitude = 4.0;
    final waveLength = size.width;
    wavePath.moveTo(bodyRect.left, bodyRect.bottom);
    wavePath.lineTo(bodyRect.left, fillTop);
    for (double x = 0; x <= size.width; x += 4) {
      final y = fillTop + sin((x / waveLength * 2 * pi) + wavePhase) * (fillRatio > 0.02 ? waveAmplitude : 0);
      wavePath.lineTo(bodyRect.left + x, y);
    }
    wavePath.lineTo(bodyRect.right, bodyRect.bottom);
    wavePath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.75), color],
      ).createShader(bodyRect);
    canvas.drawPath(wavePath, fillPaint);

    final sheenPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 2;
    final sheenPath = Path();
    for (double x = 0; x <= size.width; x += 4) {
      final y = fillTop + sin((x / waveLength * 2 * pi) + wavePhase) * (fillRatio > 0.02 ? waveAmplitude : 0) + 3;
      if (x == 0) {
        sheenPath.moveTo(bodyRect.left + x, y);
      } else {
        sheenPath.lineTo(bodyRect.left + x, y);
      }
    }
    canvas.drawPath(sheenPath, sheenPaint..style = PaintingStyle.stroke);

    canvas.restore();

    canvas.drawRRect(
      bodyRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.surfaceOutline,
    );
  }

  @override
  bool shouldRepaint(covariant _BatteryPainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.color != color ||
        oldDelegate.wavePhase != wavePhase ||
        oldDelegate.charging != charging;
  }
}
