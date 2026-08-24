import 'package:flutter/material.dart';

import '../models/sensor_data.dart';
import '../theme/app_theme.dart';

/// Shows the phone <-> ESP32 WebSocket link status and lets the operator
/// enter/change the rover's IP, reconnect, or drop back to demo mode.
class ConnectionPanel extends StatelessWidget {
  final EspLinkState linkState;
  final String? espHost;
  final void Function(String host) onConnect;
  final VoidCallback onUseDemoMode;
  final VoidCallback onTestAlarm;

  const ConnectionPanel({
    super.key,
    required this.linkState,
    required this.espHost,
    required this.onConnect,
    required this.onUseDemoMode,
    required this.onTestAlarm,
  });

  Color get _dotColor {
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

  String get _statusText {
    switch (linkState) {
      case EspLinkState.connected:
        return 'Connected to $espHost';
      case EspLinkState.connecting:
        return 'Connecting to $espHost…';
      case EspLinkState.reconnecting:
        return 'Reconnecting to $espHost…';
      case EspLinkState.demo:
        return 'Demo mode — no rover connected';
      case EspLinkState.disconnected:
        return 'Disconnected';
      case EspLinkState.error:
        return 'Could not reach $espHost';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceOutline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _dotColor,
                  boxShadow: [BoxShadow(color: _dotColor.withValues(alpha: 0.6), blurRadius: 6)],
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _statusText,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
              if (linkState == EspLinkState.demo) ...[
                TextButton(
                  onPressed: onTestAlarm,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: AppColors.danger,
                  ),
                  child: const Text('Test alarm', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
                ),
                const SizedBox(width: 2),
              ],
              TextButton(
                onPressed: () => _openConnectSheet(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  linkState == EspLinkState.demo ? 'Connect' : 'Change',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openConnectSheet(BuildContext context) {
    final controller = TextEditingController(text: espHost ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Connect to rover', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                const Text(
                  'Enter the ESP32\'s IP address on your WiFi network (e.g. 192.168.1.42), or its AP address if you\'re connecting directly to the rover\'s hotspot.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    hintText: '192.168.1.42',
                    filled: true,
                    fillColor: AppColors.blue50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.turquoise,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      final host = controller.text.trim();
                      if (host.isEmpty) return;
                      Navigator.of(sheetContext).pop();
                      onConnect(host);
                    },
                    child: const Text('Connect', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      onUseDemoMode();
                    },
                    child: const Text('Use demo mode instead'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
