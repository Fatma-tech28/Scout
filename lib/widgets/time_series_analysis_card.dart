import 'package:flutter/material.dart';

import '../models/sensor_data.dart';
import '../theme/app_theme.dart';

enum _Trend { rising, falling, stable }

class TimeSeriesAnalysisCard extends StatelessWidget {
  final List<TimeSeriesPoint> points;
  final String unit;
  final bool isEvent;
  final String eventLabel;

  const TimeSeriesAnalysisCard({
    super.key,
    required this.points,
    this.unit = '',
    this.isEvent = false,
    this.eventLabel = 'Event',
  });

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.blue50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceOutline, width: 1.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.query_stats_rounded, size: 17, color: AppColors.blue500),
              SizedBox(width: 7),
              Text(
                'Time series analysis',
                style: TextStyle(color: AppColors.textOnLight, fontWeight: FontWeight.w800, fontSize: 14.5),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isEvent) _eventStats() else _continuousStats(),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.blue500, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(color: AppColors.textOnLight, fontSize: 15, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _continuousStats() {
    final values = points.map((p) => p.value).toList();
    final avg = values.reduce((a, b) => a + b) / values.length;
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        Row(
          children: [
            _statChip('Average', '${avg.toStringAsFixed(1)}$unit'),
            _statChip('Minimum', '${minV.toStringAsFixed(1)}$unit'),
            _statChip('Maximum', '${maxV.toStringAsFixed(1)}$unit'),
          ],
        ),
        const SizedBox(height: 14),
        _trendRow(_trendOf(values)),
      ],
    );
  }

  Widget _eventStats() {
    final activeCount = points.where((p) => p.value > 0.5).length;
    final pct = (activeCount / points.length * 100).round();
    int longest = 0, current = 0;
    for (final p in points) {
      if (p.value > 0.5) {
        current += 1;
        if (current > longest) longest = current;
      } else {
        current = 0;
      }
    }

    return Row(
      children: [
        _statChip('Total events', '$activeCount'),
        _statChip('Active share', '$pct%'),
        _statChip('Longest streak', '$longest'),
      ],
    );
  }

  _Trend _trendOf(List<double> values) {
    final half = values.length ~/ 2;
    if (half == 0) return _Trend.stable;
    final firstAvg = values.sublist(0, half).reduce((a, b) => a + b) / half;
    final secondAvg = values.sublist(values.length - half).reduce((a, b) => a + b) / half;
    final delta = secondAvg - firstAvg;
    final relative = firstAvg.abs() < 0.001 ? delta.abs() : (delta.abs() / firstAvg.abs());
    if (relative < 0.03) return _Trend.stable;
    return delta > 0 ? _Trend.rising : _Trend.falling;
  }

  Widget _trendRow(_Trend trend) {
    late final IconData icon;
    late final Color color;
    late final String label;
    switch (trend) {
      case _Trend.rising:
        icon = Icons.trending_up_rounded;
        color = AppColors.warning;
        label = 'Trending up over this window';
        break;
      case _Trend.falling:
        icon = Icons.trending_down_rounded;
        color = AppColors.success;
        label = 'Trending down over this window';
        break;
      case _Trend.stable:
        icon = Icons.trending_flat_rounded;
        color = AppColors.blue500;
        label = 'Holding steady over this window';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}
