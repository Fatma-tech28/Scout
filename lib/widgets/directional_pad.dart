import 'package:flutter/material.dart';

import '../models/sensor_data.dart';
import '../theme/app_theme.dart';
import 'circular_control_button.dart';

class DirectionalPad extends StatelessWidget {
  final bool enabled;
  final void Function(DriveCommand) onPressStart;
  final VoidCallback onPressEnd;

  const DirectionalPad({
    super.key,
    required this.enabled,
    required this.onPressStart,
    required this.onPressEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularControlButton(
          icon: Icons.keyboard_arrow_up_rounded,
          enabled: enabled,
          accent: AppColors.pink,
          onPressStart: () => onPressStart(DriveCommand.forward),
          onPressEnd: onPressEnd,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularControlButton(
              icon: Icons.keyboard_arrow_left_rounded,
              enabled: enabled,
              accent: AppColors.turquoise,
              onPressStart: () => onPressStart(DriveCommand.left),
              onPressEnd: onPressEnd,
            ),
            const SizedBox(width: 26),
            CircularControlButton(
              icon: Icons.circle,
              enabled: false,
              size: 34,
              accent: AppColors.surfaceOutline,
              onPressStart: () {},
              onPressEnd: () {},
            ),
            const SizedBox(width: 26),
            CircularControlButton(
              icon: Icons.keyboard_arrow_right_rounded,
              enabled: enabled,
              accent: AppColors.turquoise,
              onPressStart: () => onPressStart(DriveCommand.right),
              onPressEnd: onPressEnd,
            ),
          ],
        ),
        const SizedBox(height: 12),
        CircularControlButton(
          icon: Icons.keyboard_arrow_down_rounded,
          enabled: enabled,
          accent: AppColors.pink,
          onPressStart: () => onPressStart(DriveCommand.backward),
          onPressEnd: onPressEnd,
        ),
      ],
    );
  }
}
