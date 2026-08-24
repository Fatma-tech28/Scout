import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/car_state.dart';
import '../widgets/alert_overlay.dart';
import 'control_page.dart';
import 'dashboard_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  StreamSubscription? _notificationSub;

  static const _pages = [ControlPage(), DashboardPage()];

  @override
  void initState() {
    super.initState();
    // PIR motion / high temperature / high humidity surface as a
    // lightweight snackbar here — they never trigger the full-screen
    // alarm, which is reserved for flame/gas (see CarState).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final car = context.read<CarState>();
      _notificationSub = car.notifications.listen((message) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CarState>(
      builder: (context, car, _) {
        return Scaffold(
          body: Stack(
            children: [
              IndexedStack(index: _index, children: _pages),
              // Mounted here (rather than inside a single tab) so the
              // critical (flame/gas) alarm stays fully visible no matter
              // which tab the operator is currently viewing. Ultrasonic
              // obstacle warnings and PIR/temp/humidity notifications
              // never reach this — see CarState.criticalAlertActive.
              if (car.criticalAlertActive)
                Positioned.fill(
                  child: AlertOverlay(alert: car.alert, onDismiss: car.dismissAlert),
                ),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.gamepad_rounded), label: 'Control'),
              BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
            ],
          ),
        );
      },
    );
  }
}
