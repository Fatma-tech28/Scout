import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sensor_data.dart';
import '../state/car_state.dart';
import '../theme/app_theme.dart';
import '../widgets/battery_visual.dart';
import '../widgets/chart_axis_labels.dart';
import '../widgets/time_series_analysis_card.dart';

class BatteryReportPage extends StatefulWidget {
  const BatteryReportPage({super.key});

  @override
  State<BatteryReportPage> createState() => _BatteryReportPageState();
}

class _BatteryReportPageState extends State<BatteryReportPage> {
  late Future<List<TimeSeriesPoint>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<CarState>().batteryHistory();
  }

  Color _levelColor(double percent) {
    if (percent <= 20) return AppColors.danger;
    if (percent <= 45) return AppColors.warning;
    return AppColors.success;
  }

  String _levelLabel(double percent, bool charging) {
    if (charging) return 'Charging';
    if (percent <= 20) return 'Low — return to base soon';
    if (percent <= 45) return 'Moderate';
    return 'Healthy';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CarState>(
      builder: (context, car, _) {
        final b = car.battery;
        final color = _levelColor(b.percent);
        return Scaffold(
          appBar: AppBar(title: const Text('Battery report')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Large animated battery visual.
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: AppColors.surfaceOutline),
                    ),
                    child: Column(
                      children: [
                        BatteryVisual(percent: b.percent, charging: b.charging),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            _levelLabel(b.percent, b.charging),
                            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.bolt_rounded,
                          label: 'Pack voltage',
                          value: '${b.voltage.toStringAsFixed(2)} V',
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.timer_outlined,
                          label: b.charging ? 'Status' : 'Est. runtime',
                          value: b.charging
                              ? 'Plugged in'
                              : (car.estimatedMinutesRemaining == null
                                  ? '—'
                                  : '${car.estimatedMinutesRemaining!.round()} min'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.blue50,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Runtime is estimated from typical component current draw (motors, servo, '
                      'sensors, ESP32/Arduino) at the current driving speed — not a measurement. '
                      'See RoverPowerModel for the assumptions and to plug in real numbers.',
                      style: TextStyle(color: AppColors.blue500, fontSize: 11, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FutureBuilder<List<TimeSeriesPoint>>(
                    future: _future,
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return Container(
                          height: 220,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.blue50,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const CircularProgressIndicator(color: AppColors.blue400),
                        );
                      }
                      final points = snap.data ?? [];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _BatteryHistoryChart(points: points),
                          const SizedBox(height: 16),
                          TimeSeriesAnalysisCard(points: points, unit: '%'),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'About the battery pack',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Powers all four drive motors from a shared pack, with a separate '
                    '5V rail feeding the sensor board. Runtime estimates assume moderate '
                    'driving speed; expect shorter runtime during obstacle-avoidance or '
                    'max-speed escape sequences.',
                    style: TextStyle(color: AppColors.textSecondary, height: 1.5),
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

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.blue500, size: 18),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/// Battery level over time suits a filled area/line chart best (a
/// continuous percentage), matching the trend-chart style used elsewhere.
class _BatteryHistoryChart extends StatelessWidget {
  final List<TimeSeriesPoint> points;
  const _BatteryHistoryChart({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: AppColors.blue400)));
    }
    final spots = <FlSpot>[for (int i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].value)];

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
      decoration: BoxDecoration(color: AppColors.blue50, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Battery level', style: TextStyle(color: AppColors.textOnLight, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 2),
          const Text('Last readings, in %', style: TextStyle(color: AppColors.blue500, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 18),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.blue100, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: 25,
                      getTitlesWidget: (v, meta) =>
                          Text('${v.toInt()}', style: const TextStyle(color: AppColors.blue500, fontSize: 10)),
                    ),
                  ),
                  bottomTitles: AxisTitles(sideTitles: evenlySpacedTimeTitles(points)),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.blue500,
                    getTooltipItems: (spots) => spots
                        .map((s) => LineTooltipItem('${s.y.toStringAsFixed(0)}%', const TextStyle(color: Colors.white, fontSize: 11)))
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.25,
                    color: AppColors.success,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.success.withValues(alpha: 0.35), AppColors.success.withValues(alpha: 0.02)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
