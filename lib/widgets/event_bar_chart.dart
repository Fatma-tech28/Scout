import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/sensor_data.dart';
import '../theme/app_theme.dart';
import 'chart_axis_labels.dart';

/// Bar chart for binary/event sensor history (flame, PIR motion). A time
/// series of 0/1 events reads far better as bars than as a line — each
/// bar is either "up" (event) or flat (clear), so spikes are obvious at
/// a glance.
class EventBarChart extends StatelessWidget {
  final List<TimeSeriesPoint> points;
  final String eventLabel;
  final Color color;

  const EventBarChart({super.key, required this.points, required this.eventLabel, required this.color});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator(color: AppColors.blue400)));
    }

    final activeCount = points.where((p) => p.value > 0.5).length;
    final activePct = (activeCount / points.length * 100).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
      decoration: BoxDecoration(color: AppColors.blue50, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Last ${points.length} readings', style: const TextStyle(color: AppColors.textOnLight, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 2),
          Text('$eventLabel in $activePct% of recent readings', style: const TextStyle(color: AppColors.blue500, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 18),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: 1.15,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 0.25,
                  getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.blue100, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: evenlySpacedTimeTitles(points)),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.blue500,
                    getTooltipItem: (group, groupIdx, rod, rodIdx) => BarTooltipItem(
                      rod.toY > 0.5 ? eventLabel : 'Clear',
                      const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
                barGroups: [
                  for (int i = 0; i < points.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: points[i].value > 0.5 ? 1 : 0.06,
                          width: (200 / points.length).clamp(4, 14).toDouble(),
                          color: points[i].value > 0.5 ? color : AppColors.blue200,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ],
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
