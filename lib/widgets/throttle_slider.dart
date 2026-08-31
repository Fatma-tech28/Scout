import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Vertical drag-to-set throttle for Manual mode, styled after the
/// previewed mockup: a tall rounded track with a red→pink→turquoise
/// fill (low speed reads as "hot"/aggressive-feeling red at the bottom
/// of the scale is intentionally avoided — see gradient stops below —
/// fill grows upward from empty at 0 to full at 100) and a draggable
/// circular thumb that always shows the live percent.
///
/// Dragging updates [onChanged] live (not just on release) so — per
/// CarState.setManualSpeed — a held D-pad direction re-sends the drive
/// command immediately at the new speed while the operator drags.
class ThrottleSlider extends StatefulWidget {
  final int value; // 0-100
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final double width;
  final double height;

  const ThrottleSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
    this.width = 42,
    this.height = 196,
  });

  @override
  State<ThrottleSlider> createState() => _ThrottleSliderState();
}

class _ThrottleSliderState extends State<ThrottleSlider> {
  double get _fraction => ((widget.value - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);

  void _updateFromLocalY(double localY, double trackHeight) {
    final clampedY = localY.clamp(0.0, trackHeight);
    // Track is drawn bottom-up: y=0 (top) is 100%, y=trackHeight (bottom) is 0%.
    final fraction = 1 - (clampedY / trackHeight);
    final raw = widget.min + fraction * (widget.max - widget.min);
    widget.onChanged(raw.round());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'SPEED',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (d) => _updateFromLocalY(d.localPosition.dy, widget.height),
          onVerticalDragUpdate: (d) => _updateFromLocalY(d.localPosition.dy, widget.height),
          onTapDown: (d) => _updateFromLocalY(d.localPosition.dy, widget.height),
          child: Container(
            width: widget.width,
            height: widget.height,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.surfaceOutline),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trackHeight = constraints.maxHeight;
                final fillHeight = trackHeight * _fraction;
                final thumbSize = widget.width - 8 + 14.0;
                final thumbY = (trackHeight - fillHeight - thumbSize / 2).clamp(-thumbSize / 2, trackHeight - thumbSize / 2);
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(color: AppColors.blue50),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: double.infinity,
                          height: fillHeight,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [AppColors.turquoise, AppColors.pink, AppColors.danger],
                              stops: [0.0, 0.55, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: thumbY,
                      child: Container(
                        width: thumbSize,
                        height: thumbSize,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.pink, width: 3),
                          boxShadow: [BoxShadow(color: AppColors.pink.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3))],
                        ),
                        child: Text(
                          '${widget.value}%',
                          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 12.5),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
