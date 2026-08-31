import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Horizontal cap slider shown in Auto mode. Unlike the manual throttle
/// (direct speed control), this sets a ceiling: the autonomous driving
/// loop in CarState reads this value on every tick and never drives
/// faster than it, even on an open, obstacle-free stretch.
///
/// Built as a plain GestureDetector + Stack (same approach as
/// ThrottleSlider) rather than Flutter's built-in Slider with a custom
/// SliderTrackShape/SliderComponentShape override — overriding those
/// internal paint() signatures broke across a Flutter SDK bump (the CI
/// build uses whatever "stable" resolves to at run time), so this
/// sidesteps that entirely while keeping the same gradient look.
class AutoSpeedCapCard extends StatefulWidget {
  final int value; // 0-100
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const AutoSpeedCapCard({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
  });

  @override
  State<AutoSpeedCapCard> createState() => _AutoSpeedCapCardState();
}

class _AutoSpeedCapCardState extends State<AutoSpeedCapCard> {
  double get _fraction =>
      ((widget.value - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);

  void _updateFromLocalX(double localX, double trackWidth) {
    final clampedX = localX.clamp(0.0, trackWidth);
    final fraction = clampedX / trackWidth;
    final raw = widget.min + fraction * (widget.max - widget.min);
    widget.onChanged(raw.round());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Max auto speed', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
              const Spacer(),
              Text('${widget.value}%', style: const TextStyle(color: AppColors.pink, fontWeight: FontWeight.w800, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final trackWidth = constraints.maxWidth;
              final fillWidth = trackWidth * _fraction;
              const thumbSize = 24.0;
              final thumbX = (fillWidth - thumbSize / 2).clamp(-thumbSize / 2, trackWidth - thumbSize / 2);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (d) => _updateFromLocalX(d.localPosition.dx, trackWidth),
                onHorizontalDragUpdate: (d) => _updateFromLocalX(d.localPosition.dx, trackWidth),
                onTapDown: (d) => _updateFromLocalX(d.localPosition.dx, trackWidth),
                child: SizedBox(
                  height: 24,
                  width: trackWidth,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.centerLeft,
                    children: [
                      // Inactive track.
                      Container(
                        height: 10,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceOutline,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      // Active (gradient) fill.
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          height: 10,
                          width: fillWidth.clamp(0, trackWidth),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [AppColors.turquoise, AppColors.pink]),
                          ),
                        ),
                      ),
                      // Thumb.
                      Positioned(
                        left: thumbX,
                        child: Container(
                          width: thumbSize,
                          height: thumbSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surface,
                            border: Border.all(color: AppColors.pink, width: 3),
                            boxShadow: [BoxShadow(color: AppColors.pink.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'Caps how fast the car drives itself — it will never exceed this, '
            'even at full throttle in an open stretch.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.35),
          ),
        ],
      ),
    );
  }
}
