import 'package:flutter/material.dart';

import '../models/sensor_data.dart';
import '../theme/app_theme.dart';

class StatusHeader extends StatelessWidget {
  final CarStatus status;
  final bool alertActive;
  final String alertLabel;
  final bool alertsEnabled;
  final VoidCallback onToggleAlerts;

  const StatusHeader({
    super.key,
    required this.status,
    required this.alertActive,
    required this.alertLabel,
    required this.alertsEnabled,
    required this.onToggleAlerts,
  });

  String get _phaseLabel {
    switch (status.phase) {
      case NavPhase.idle:
        return 'Idle';
      case NavPhase.driving:
        return 'Driving';
      case NavPhase.obstacleStop:
        return 'Obstacle — stopping';
      case NavPhase.reversing:
        return 'Reversing';
      case NavPhase.scanningRight:
        return 'Scanning right';
      case NavPhase.scanningLeft:
        return 'Scanning left';
      case NavPhase.escaping:
        return 'Escaping — fire detected';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Spacer(),
              _AlertMuteButton(enabled: alertsEnabled, onTap: onToggleAlerts),
              const SizedBox(width: 8),
              _ModePill(mode: status.mode),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${status.speedPercent}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'speed % · $_phaseLabel',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              if (alertActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.danger),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_rounded, color: AppColors.danger, size: 15),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 110),
                        child: Text(
                          alertLabel,
                          maxLines: 2,
                          style: const TextStyle(color: AppColors.danger, fontSize: 10.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Global mute for the flame/gas alarm (voice + full-screen overlay).
/// Turning it off silences the alarm system completely — including any
/// alarm currently sounding — until tapped again. Sensor readings and
/// notifications (PIR/temp/humidity) are unaffected either way.
class _AlertMuteButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _AlertMuteButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.textSecondary : AppColors.danger;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled ? Colors.transparent : AppColors.danger.withValues(alpha: 0.12),
            border: Border.all(color: enabled ? AppColors.surfaceOutline : AppColors.danger),
          ),
          child: Icon(
            enabled ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
            color: color,
            size: 16,
          ),
        ),
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  final DriveMode mode;
  const _ModePill({required this.mode});

  @override
  Widget build(BuildContext context) {
    final isAuto = mode == DriveMode.auto;
    final color = isAuto ? AppColors.turquoise : AppColors.pink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        isAuto ? 'AUTO' : 'MANUAL',
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5),
      ),
    );
  }
}
