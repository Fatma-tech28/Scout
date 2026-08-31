import 'package:flutter/material.dart';

import '../models/sensor_data.dart';
import '../theme/app_theme.dart';

class AlertOverlay extends StatefulWidget {
  final AlertEvent alert;
  final VoidCallback onDismiss;

  const AlertOverlay({super.key, required this.alert, required this.onDismiss});

  @override
  State<AlertOverlay> createState() => _AlertOverlayState();
}

class _AlertOverlayState extends State<AlertOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  IconData get _icon {
    switch (widget.alert.source) {
      case AlertSource.flame:
        return Icons.local_fire_department_rounded;
      case AlertSource.ultrasonic:
        return Icons.front_hand_rounded;
      case AlertSource.gas:
        return Icons.cloud_rounded;
      case AlertSource.pir:
        return Icons.accessibility_new_rounded;
      case AlertSource.none:
        return Icons.warning_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final danger = widget.alert.severity == AlertSeverity.danger;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = _pulse.value;
        return Container(
          color: Color.lerp(
            AppColors.danger.withValues(alpha: 0.88),
            AppColors.danger.withValues(alpha: 0.97),
            t,
          ),
          child: child,
        );
      },
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.15),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(_icon, color: Colors.white, size: 56),
                ),
                const SizedBox(height: 24),
                Text(
                  danger ? 'DANGER' : 'WARNING',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.alert.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500, height: 1.4),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.onDismiss,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: const Text(
                      'STOP ALERT',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
