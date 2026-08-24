import 'package:flutter/material.dart';

import '../models/sensor_data.dart';
import '../theme/app_theme.dart';

class ModeToggle extends StatelessWidget {
  final DriveMode mode;
  final ValueChanged<DriveMode> onChanged;

  const ModeToggle({super.key, required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceOutline),
      ),
      child: Row(
        children: [
          _segment(context, 'Manual', DriveMode.manual, AppColors.pink),
          _segment(context, 'Auto', DriveMode.auto, AppColors.turquoise),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, String label, DriveMode value, Color accent) {
    final selected = mode == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? accent : Colors.transparent),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? accent : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
