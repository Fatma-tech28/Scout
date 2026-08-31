import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sensor_data.dart';
import '../state/car_state.dart';
import '../theme/app_theme.dart';
import '../widgets/auto_speed_cap_card.dart';
import '../widgets/connection_panel.dart';
import '../widgets/directional_pad.dart';
import '../widgets/mode_toggle.dart';
import '../widgets/status_header.dart';
import '../widgets/throttle_slider.dart';
import 'battery_report_page.dart';

class ControlPage extends StatelessWidget {
  const ControlPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CarState>(
      builder: (context, car, _) {
        final status = car.status;
        final manual = status.mode == DriveMode.manual;

        return Scaffold(
          appBar: AppBar(title: const Text('Inspection Rover')),
          body: SafeArea(
            child: Stack(
              children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Column(
                      children: [
                        ConnectionPanel(
                          linkState: car.linkState,
                          espHost: car.espHost,
                          onRetry: () => car.connectToEsp('192.168.4.1'),
                        ),
                        const SizedBox(height: 8),
                        StatusHeader(
                          status: status,
                          alertActive: car.alertActive,
                          alertLabel: car.alert.message,
                          alertsEnabled: car.alertsEnabled,
                          onToggleAlerts: () => car.setAlertsEnabled(!car.alertsEnabled),
                        ),
                        const SizedBox(height: 12),
                        ModeToggle(
                          mode: status.mode,
                          onChanged: (m) => car.setMode(m),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: manual
                              ? _ManualModePanel(car: car, status: status)
                              : _AutoModePanel(car: car),
                        ),
                        _BatteryButton(battery: car.battery),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: car.alertActive ? car.dismissAlert : null,
                            icon: const Icon(Icons.notifications_off_rounded),
                            label: const Text('Stop Alert'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                              side: BorderSide(color: car.alertActive ? AppColors.danger : AppColors.surfaceOutline),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Manual mode body: the D-pad plus a vertical throttle slider that sets
/// the speed every press uses. Dragging the throttle while a direction
/// is held re-sends the command live at the new speed (see
/// CarState.setManualSpeed).
class _ManualModePanel extends StatelessWidget {
  final CarState car;
  final CarStatus status;
  const _ManualModePanel({required this.car, required this.status});

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder + a min-height ConstrainedBox centers the D-pad and
    // throttle when there's room, but lets the panel scroll instead of
    // overflowing/overlapping the battery button on shorter screens —
    // same safety net _AutoModePanel already had.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  DirectionalPad(
                    enabled: status.connected,
                    onPressStart: (cmd) => car.pressCommand(cmd),
                    onPressEnd: () => car.releaseCommand(),
                  ),
                  const SizedBox(width: 24),
                  ThrottleSlider(
                    value: car.manualSpeedPercent,
                    min: CarState.minAdjustableSpeed,
                    max: CarState.maxSpeed,
                    onChanged: (v) => car.setManualSpeed(v),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AutoModePanel extends StatelessWidget {
  final CarState car;
  const _AutoModePanel({required this.car});

  String get _phaseCaption {
    switch (car.status.phase) {
      case NavPhase.idle:
        return 'Starting patrol…';
      case NavPhase.driving:
        return 'Patrolling forward, capped at ${car.autoMaxSpeedPercent}% speed';
      case NavPhase.obstacleStop:
        return 'Obstacle ahead — stopping';
      case NavPhase.reversing:
        return 'Reversing two steps';
      case NavPhase.scanningRight:
        return 'Servo scanning right';
      case NavPhase.scanningLeft:
        return 'Right blocked — scanning left';
      case NavPhase.escaping:
        return 'Flame detected — reversing at max speed';
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [AppColors.turquoise.withValues(alpha: 0.25), AppColors.surface],
              ),
              border: Border.all(color: AppColors.turquoise, width: 2),
            ),
            child: const Icon(Icons.explore_rounded, color: AppColors.turquoise, size: 68),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _phaseCaption,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 18),
          AutoSpeedCapCard(
            value: car.autoMaxSpeedPercent,
            min: CarState.minAdjustableSpeed,
            max: CarState.maxSpeed,
            onChanged: (v) => car.setAutoMaxSpeed(v),
          ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Replaces the old three-chip sensor strip. A single full-width button
/// that opens the battery report page, with a live percent readout and a
/// small level-colored fill so status is visible at a glance.
class _BatteryButton extends StatelessWidget {
  final BatteryStatus battery;
  const _BatteryButton({required this.battery});

  Color get _color {
    if (battery.percent <= 20) return AppColors.danger;
    if (battery.percent <= 45) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BatteryReportPage()),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.surfaceOutline),
          ),
          child: Row(
            children: [
              Icon(
                battery.charging ? Icons.battery_charging_full_rounded : Icons.battery_std_rounded,
                color: color,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Battery', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (battery.percent / 100).clamp(0, 1).toDouble(),
                        minHeight: 5,
                        backgroundColor: AppColors.surfaceOutline,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${battery.percent.round()}%',
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
