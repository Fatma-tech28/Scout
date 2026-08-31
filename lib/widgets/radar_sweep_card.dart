import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/car_connection_service.dart';
import '../state/car_state.dart';
import '../theme/app_theme.dart';

/// Live radar-style preview of the HC-SR04 ultrasonic sensor riding the
/// servo sweep (GPIO18 servo, GPIO17 Trig / GPIO16 Echo per the wiring
/// plan). Embedded directly in the PIR report page rather than as its
/// own page, with an on/off toggle so the servo isn't left sweeping
/// indefinitely — flip it on to watch a live sweep, off to free the
/// servo for other tasks.
class RadarSweepCard extends StatefulWidget {
  const RadarSweepCard({super.key});

  @override
  State<RadarSweepCard> createState() => _RadarSweepCardState();
}

class _RadarSweepCardState extends State<RadarSweepCard> with SingleTickerProviderStateMixin {
  static const int _maxAngle = 180;
  static const double _maxRangeCm = 400;

  final List<double> _intensity = List.filled(_maxAngle + 1, 0.0);
  final List<double?> _distanceAtAngle = List.filled(_maxAngle + 1, null);
  RadarSweepReading? _lastProcessed;

  late final AnimationController _decayTicker = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 16),
  )..repeat();

  @override
  void dispose() {
    _decayTicker.dispose();
    super.dispose();
  }

  void _ingest(RadarSweepReading? reading) {
    if (reading == null || identical(reading, _lastProcessed)) return;
    _lastProcessed = reading;
    final a = reading.angleDegrees.clamp(0, _maxAngle);
    if (reading.distanceCm != null) {
      _intensity[a] = 1.0;
      _distanceAtAngle[a] = reading.distanceCm;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CarState>(
      builder: (context, car, _) {
        _ingest(car.radarReading);
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.blue50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.surfaceOutline, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Radar sweep', style: TextStyle(color: AppColors.textOnLight, fontWeight: FontWeight.w800, fontSize: 13)),
                        SizedBox(height: 2),
                        Text('Servo + ultrasonic, live', style: TextStyle(color: AppColors.blue500, fontSize: 10.5, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Switch(
                    value: car.radarActive,
                    activeColor: AppColors.turquoise,
                    onChanged: (v) {
                      if (!v) {
                        // Reset the trail so re-enabling starts clean.
                        for (var i = 0; i < _intensity.length; i++) {
                          _intensity[i] = 0;
                          _distanceAtAngle[i] = null;
                        }
                      }
                      car.setRadarActive(v);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (car.radarActive)
                _buildRadarScreen(car.radarReading)
              else
                _buildOffState(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRadarScreen(RadarSweepReading? reading) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(color: const Color(0xFF0B1220), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.turquoise.withValues(alpha: 0.15),
                  border: Border.all(color: AppColors.turquoise.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('● LIVE — real sweep', style: TextStyle(color: AppColors.turquoise, fontSize: 9.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 220 / 140,
            child: AnimatedBuilder(
              animation: _decayTicker,
              builder: (context, _) {
                // Gentle decay each frame so old hits fade like a real sweep trail.
                for (var i = 0; i < _intensity.length; i++) {
                  if (_intensity[i] > 0) _intensity[i] = (_intensity[i] - 0.012).clamp(0.0, 1.0);
                }
                return CustomPaint(
                  painter: _RadarPainter(
                    currentAngle: reading?.angleDegrees ?? 0,
                    intensity: _intensity,
                    distanceAtAngle: _distanceAtAngle,
                    maxRangeCm: _maxRangeCm,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _readout('Angle', reading == null ? '--°' : '${reading.angleDegrees}°'),
              _readout('Dist', reading?.distanceCm == null ? 'no echo' : '${reading!.distanceCm!.toStringAsFixed(0)} cm'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _readout(String label, String value) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(color: Color(0xFF8FA0C4), fontSize: 9.5),
        children: [
          TextSpan(text: '$label: '),
          TextSpan(text: value, style: const TextStyle(color: Color(0xFFEAF0FB), fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildOffState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26),
      decoration: BoxDecoration(color: const Color(0xFF0B1220), borderRadius: BorderRadius.circular(16)),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.podcasts_rounded, color: Color(0xFF5C6A8A), size: 26),
          SizedBox(height: 6),
          Text('Radar is off', style: TextStyle(color: Color(0xFF5C6A8A), fontSize: 11.5, fontWeight: FontWeight.w700)),
          SizedBox(height: 2),
          Text('Servo is free for other tasks', style: TextStyle(color: Color(0xFF5C6A8A), fontSize: 10)),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final int currentAngle;
  final List<double> intensity;
  final List<double?> distanceAtAngle;
  final double maxRangeCm;

  _RadarPainter({
    required this.currentAngle,
    required this.intensity,
    required this.distanceAtAngle,
    required this.maxRangeCm,
  });

  Offset _toXY(Offset origin, double maxR, int angleDeg, double distCm) {
    final rad = (180 - angleDeg) * pi / 180;
    final r = min((distCm / maxRangeCm) * maxR, maxR);
    return Offset(origin.dx + r * cos(rad), origin.dy - r * sin(rad));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height - 6);
    final maxR = min(size.width / 2 - 6, size.height - 12);

    // Range rings + baseline.
    final ringPaint = Paint()
      ..color = const Color(0x408FA0C4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int m = 1; m <= 4; m++) {
      final r = (m / 4) * maxR;
      canvas.drawArc(Rect.fromCircle(center: origin, radius: r), pi, pi, false, ringPaint);
    }
    canvas.drawLine(Offset(origin.dx - maxR, origin.dy), Offset(origin.dx + maxR, origin.dy), ringPaint);

    // Trail of past hits, faded by intensity.
    for (int a = 0; a <= 180; a++) {
      final heat = intensity[a];
      final dist = distanceAtAngle[a];
      if (heat <= 0.03 || dist == null) continue;
      final p = _toXY(origin, maxR, a, dist);
      canvas.drawCircle(
        p,
        3,
        Paint()..color = AppColors.blue300.withValues(alpha: heat.clamp(0.0, 1.0)),
      );
    }

    // Current sweep line, faded toward the tip.
    final tip = _toXY(origin, maxR, currentAngle, maxRangeCm);
    final sweepPaint = Paint()
      ..shader = LinearGradient(
        colors: [AppColors.turquoise.withValues(alpha: 0.9), AppColors.turquoise.withValues(alpha: 0.0)],
      ).createShader(Rect.fromPoints(origin, tip))
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(origin, tip, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => true;
}
