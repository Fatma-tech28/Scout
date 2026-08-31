import 'package:flutter/material.dart';

import '../models/sensor_data.dart';
import '../theme/app_theme.dart';
import 'half_gauge_painter.dart';

class HalfGaugeCard extends StatelessWidget {
  final SensorKind kind;
  final String bigValue;
  final String statusLabel;
  final Color statusColor;
  final double value;
  final IconData icon;
  final VoidCallback onTap;

  const HalfGaugeCard({
    super.key,
    required this.kind,
    required this.bigValue,
    required this.statusLabel,
    required this.statusColor,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            color: AppColors.blue50,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.surfaceOutline, width: 1.3),
            boxShadow: const [BoxShadow(color: Color(0x1A395886), blurRadius: 14, offset: Offset(0, 6))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 15, color: AppColors.blue500),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      kind.label,
                      style: const TextStyle(
                        color: AppColors.textOnLight,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 17, color: AppColors.blue400),
                ],
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxByWidth = constraints.maxWidth;
                    final maxByHeight = constraints.maxHeight * 2;
                    final gaugeWidth = maxByWidth < maxByHeight ? maxByWidth : maxByHeight;
                    return Center(
                      child: SizedBox(
                        width: gaugeWidth,
                        height: gaugeWidth / 2,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: value, end: value),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                          builder: (context, animatedValue, child) {
                            return CustomPaint(
                              painter: HalfGaugePainter(
                                value: animatedValue,
                                trackColor: AppColors.blue100,
                                valueGradient: AppColors.gaugeGradient,
                              ),
                              child: child,
                            );
                          },
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: FittedBox(
                                child: Text(
                                  bigValue,
                                  style: const TextStyle(
                                    color: AppColors.textOnLight,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
