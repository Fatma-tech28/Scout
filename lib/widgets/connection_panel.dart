import 'package:flutter/material.dart';

import '../models/sensor_data.dart';
import '../theme/app_theme.dart';

/// Simple, no-manual-entry connection status indicator. The ESP32 always
/// runs its own WiFi hotspot at a fixed address (192.168.4.1) in AP mode,
/// and the app auto-connects to it on startup (see main.dart) — so there's
/// nothing for the operator to type in normal use.
///
/// Tapping this while NOT connected forces an immediate retry, rather
/// than waiting for the automatic reconnect backoff timer. Useful right
/// after joining the rover's hotspot on your phone, or if the ESP32
/// wasn't powered on yet when the app launched.
class ConnectionPanel extends StatelessWidget {
  final EspLinkState linkState;
  final String? espHost;
  final VoidCallback onRetry;

  const ConnectionPanel({
    super.key,
    required this.linkState,
    required this.espHost,
    required this.onRetry,
  });

  bool get _connected => linkState == EspLinkState.connected;

  Color get _color {
    switch (linkState) {
      case EspLinkState.connected:
        return AppColors.success;
      case EspLinkState.connecting:
      case EspLinkState.reconnecting:
        return AppColors.warning;
      case EspLinkState.demo:
        return AppColors.blue400;
      case EspLinkState.disconnected:
      case EspLinkState.error:
        return AppColors.danger;
    }
  }

  String get _label {
    switch (linkState) {
      case EspLinkState.connected:
        return 'Connected to rover';
      case EspLinkState.connecting:
        return 'Connecting to rover…';
      case EspLinkState.reconnecting:
        return 'Reconnecting…';
      case EspLinkState.demo:
        return 'Starting up…';
      case EspLinkState.disconnected:
        return 'Not connected — tap to retry';
      case EspLinkState.error:
        return 'Could not reach rover — tap to retry';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _connected ? null : onRetry,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _connected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                _label,
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
