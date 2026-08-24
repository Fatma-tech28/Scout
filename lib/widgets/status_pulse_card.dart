import 'package:flutter/material.dart';

import '../models/sensor_data.dart';
import '../theme/app_theme.dart';

class StatusPulseCard extends StatelessWidget {
  final SensorKind kind;
  final IconData icon;
  final bool active;
  final String bigValue;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onTap;

  const StatusPulseCard({
    super.key,
    required this.kind,
    required this.icon,
    required this.active,
    required this.bigValue,
    required this.statusLabel,
    required this.statusColor,
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
                child: Center(
                  child: _Pulse(active: active, color: statusColor, icon: icon, label: bigValue),
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

class _Pulse extends StatefulWidget {
  final bool active;
  final Color color;
  final IconData icon;
  final String label;
  const _Pulse({required this.active, required this.color, required this.icon, required this.label});

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _Pulse old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.active) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxHeight < constraints.maxWidth ? constraints.maxHeight : constraints.maxWidth;
        final dim = size.clamp(0, 84).toDouble();
        return AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = widget.active ? _c.value : 0.0;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    if (widget.active)
                      Container(
                        width: dim + t * 16,
                        height: dim + t * 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.color.withValues(alpha: 0.16 * (1 - t)),
                        ),
                      ),
                    Container(
                      width: dim,
                      height: dim,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.color.withValues(alpha: 0.14),
                        border: Border.all(color: widget.color, width: 1.6),
                      ),
                      child: Icon(widget.icon, color: widget.color, size: dim * 0.46),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.label,
                  style: TextStyle(color: widget.color, fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
