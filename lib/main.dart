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
      create: (_) => CarState(MockCarConnectionService())..init(),
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
