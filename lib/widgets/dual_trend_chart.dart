import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/sensor_data.dart';
import '../theme/app_theme.dart';
import 'chart_axis_labels.dart';

/// Dual-line chart for combined temperature + humidity history — two
/// related continuous readings suit an overlaid two-series line chart
/// better than a single trend line, so trends between them are visible
/// together (e.g. humidity dropping as temperature rises).
class DualTrendChart extends StatelessWidget {
  final List<TimeSeriesPoint> temperature;
  final List<TimeSeriesPoint> humidity;

  const DualTrendChart({super.key, required this.temperature, required this.humidity});

  @override
  Widget build(BuildContext context) {
    if (temperature.isEmpty || humidity.isEmpty) {
      return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator(color: AppColors.blue400)));
    }

    final tempSpots = <FlSpot>[for (int i = 0; i < temperature.length; i++) FlSpot(i.toDouble(), temperature[i].value)];
    final humiditySpots = <FlSpot>[for (int i = 0; i < humidity.length; i++) FlSpot(i.toDouble(), humidity[i].value)];
    final allValues = [...temperature.map((p) => p.value), ...humidity.map((p) => p.value)];
    final minY = allValues.reduce((a, b) => a < b ? a : b);
    final maxY = allValues.reduce((a, b) => a > b ? a : b);
    final pad = ((maxY - minY).abs() * 0.2).clamp(1, double.infinity);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
      decoration: BoxDecoration(color: AppColors.blue50, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Last ${temperature.length} readings', style: const TextStyle(color: AppColors.textOnLight, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 6),
          Row(
            children: [
              _legendDot(AppColors.blue500, 'Temp (°C)'),
              const SizedBox(width: 14),
              _legendDot(AppColors.turquoise, 'Humidity (%)'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minY: (minY - pad).toDouble(),
                maxY: (maxY + pad).toDouble(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: ((maxY - minY + pad * 2) / 4).clamp(1, double.infinity).toDouble(),
                  getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.blue100, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (v, meta) => Text(v.toStringAsFixed(0), style: const TextStyle(color: AppColors.blue500, fontSize: 10)),
                    ),
                  ),
                  bottomTitles: AxisTitles(sideTitles: evenlySpacedTimeTitles(temperature)),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.blue500,
                    getTooltipItems: (spots) => spots
                        .map((s) => LineTooltipItem(s.y.toStringAsFixed(1), const TextStyle(color: Colors.white, fontSize: 11)))
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: tempSpots,
                    isCurved: true,
                    curveSmoothness: 0.25,
                    color: AppColors.blue500,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: humiditySpots,
                    isCurved: true,
                    curveSmoothness: 0.25,
                    color: AppColors.turquoise,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.textOnLight, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
