import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sensor_data.dart';
import '../state/car_state.dart';
import '../theme/app_theme.dart';
import '../widgets/half_gauge_card.dart';
import '../widgets/status_pulse_card.dart';
import 'sensor_detail_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CarState>(
      builder: (context, car, _) {
        final s = car.sensors;
        return Scaffold(
          appBar: AppBar(title: const Text('Sensor Dashboard')),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 14.0;
                  final cellWidth = (constraints.maxWidth - spacing) / 2;
                  final cellHeight = (constraints.maxHeight - spacing) / 2;
                  final aspectRatio = cellWidth / cellHeight;

                  return GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: spacing,
                    crossAxisSpacing: spacing,
                    childAspectRatio: aspectRatio,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      StatusPulseCard(
                        kind: SensorKind.flame,
                        icon: Icons.local_fire_department_rounded,
                        active: s.flameDetected,
                        bigValue: s.flameDetected ? 'FIRE' : 'Clear',
                        statusLabel: s.flameDetected ? 'Danger' : 'Normal',
                        statusColor: s.flameDetected ? AppColors.danger : AppColors.success,
                        onTap: () => _openDetail(context, SensorKind.flame),
                      ),
                      HalfGaugeCard(
                        kind: SensorKind.gas,
                        icon: Icons.cloud_rounded,
                        value: (s.gasRaw / SensorThresholds.gasMaxRaw).clamp(0, 1).toDouble(),
                        bigValue: s.gasRaw.toStringAsFixed(0),
                        statusLabel: s.gasRaw >= SensorThresholds.gasDangerRaw ? 'Danger' : 'Normal',
                        statusColor: s.gasRaw >= SensorThresholds.gasDangerRaw ? AppColors.danger : AppColors.success,
                        onTap: () => _openDetail(context, SensorKind.gas),
                      ),
                      StatusPulseCard(
                        kind: SensorKind.pir,
                        icon: Icons.accessibility_new_rounded,
                        active: s.pirMotion,
                        bigValue: s.pirMotion ? 'Motion' : 'Still',
                        statusLabel: s.pirMotion ? 'Detected' : 'Normal',
                        statusColor: s.pirMotion ? AppColors.warning : AppColors.success,
                        onTap: () => _openDetail(context, SensorKind.pir),
                      ),
                      HalfGaugeCard(
                        kind: SensorKind.humidityTemp,
                        icon: Icons.thermostat_rounded,
                        value: (s.temperature / SensorThresholds.tempMaxC).clamp(0, 1).toDouble(),
                        bigValue: '${s.temperature.toStringAsFixed(0)}°/${s.humidity.toStringAsFixed(0)}%',
                        statusLabel: s.temperature >= SensorThresholds.tempNotifyC ? 'Hot' : 'Normal',
                        statusColor: s.temperature >= SensorThresholds.tempNotifyC ? AppColors.warning : AppColors.success,
                        onTap: () => _openDetail(context, SensorKind.humidityTemp),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _openDetail(BuildContext context, SensorKind kind) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SensorDetailPage(kind: kind)),
    );
  }
}
