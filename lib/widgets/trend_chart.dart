import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/sensor_data.dart';
import '../theme/app_theme.dart';
import 'chart_axis_labels.dart';

/// Line + area chart for historical sensor data, styled after the
/// reference "Credit Score History" card: light card, gridlines, a
/// gradient-filled trend line, and a headline delta above it.
class TrendChart extends StatelessWidget {
  final List<TimeSeriesPoint> points;
  final String unit;

  const TrendChart({super.key, required this.points, required this.unit});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator(color: AppColors.blue400)));
    }

    final spots = <FlSpot>[
      for (int i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].value),
    ];
    final minY = points.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    final maxY = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final pad = ((maxY - minY).abs() * 0.2).clamp(1, double.infinity);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
      decoration: BoxDecoration(
        color: AppColors.blue50,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Last ${points.length} readings',
            style: const TextStyle(color: AppColors.textOnLight, fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 2),
          Text(
            unit.isEmpty ? 'Event trend' : 'Values in $unit',
            style: const TextStyle(color: AppColors.blue500, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 18),
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
                      getTitlesWidget: (v, meta) => Text(
                        v.toStringAsFixed(0),
                        style: const TextStyle(color: AppColors.blue500, fontSize: 10),
                      ),
                    ),
                  ),
                  // Only start/mid/end labels — see chart_axis_labels.dart
                  // for why this replaced the old interval-based approach.
                  bottomTitles: AxisTitles(sideTitles: evenlySpacedTimeTitles(points)),
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
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.25,
                    color: AppColors.blue500,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.blue300.withValues(alpha: 0.45), AppColors.blue100.withValues(alpha: 0.02)],
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
