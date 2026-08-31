import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/sensor_data.dart';
import '../theme/app_theme.dart';

/// Builds bottom-axis time labels for the sensor history charts.
///
/// Previously every chart picked an `interval` for [SideTitles] and let
/// fl_chart decide which indices to render passing through that filter —
/// with short/narrow chart widths that still produced overlapping,
/// unreadable timestamps (a label under every bar). This instead always
/// renders exactly 3 labels — start, middle, end of the window — so
/// there's never crowding regardless of point count or chart width.
SideTitles evenlySpacedTimeTitles(List<TimeSeriesPoint> points, {double reservedSize = 26}) {
  if (points.isEmpty) {
    return const SideTitles(showTitles: false);
  }
  final lastIndex = points.length - 1;
  final midIndex = lastIndex ~/ 2;
  final labelIndices = <int>{0, midIndex, lastIndex};

  return SideTitles(
    showTitles: true,
    reservedSize: reservedSize,
    // interval=1 so fl_chart evaluates every index; we do our own
    // filtering below to keep exactly the 3 labels we want.
    interval: 1,
    getTitlesWidget: (v, meta) {
      final idx = v.round();
      if (idx < 0 || idx >= points.length || !labelIndices.contains(idx)) {
        return const SizedBox.shrink();
      }
      // Align the start label left, end label right, middle centered, so
      // none of the three labels overlaps the chart edges or each other.
      final Alignment align = idx == 0
          ? Alignment.centerLeft
          : (idx == lastIndex ? Alignment.centerRight : Alignment.center);
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Align(
          alignment: align,
          child: Text(
            DateFormat.Hm().format(points[idx].time),
            style: const TextStyle(color: AppColors.blue500, fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ),
      );
    },
  );
}
