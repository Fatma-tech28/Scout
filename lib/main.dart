import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'pages/home_shell.dart';
import 'services/car_connection_service.dart';
import 'state/car_state.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const InspectionCarApp());
}

class InspectionCarApp extends StatelessWidget {
  const InspectionCarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // Starts in demo mode (init()) so the UI has something to show
      // immediately, then swaps to the real ESP32 connection right away.
      // The ESP32 always runs its own hotspot at this fixed address in
      // AP mode, so there's nothing for the operator to type — see
      // ConnectionPanel for the (tap-to-retry-only) status indicator.
      create: (_) => CarState(MockCarConnectionService())
        ..init()
        ..connectToEsp('192.168.4.1'),
      child: MaterialApp(
        title: 'Inspection Rover',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.light,
        themeMode: ThemeMode.light,
        home: const HomeShell(),
      ),
    );
  }
}
