import 'dart:async';
import 'dart:math';

import '../models/power_model.dart';
import '../models/sensor_data.dart';

abstract class CarConnectionService {
  Stream<SensorSnapshot> get sensorStream;
  Stream<bool> get connectionStream;
  Stream<BatteryStatus> get batteryStream;

  Future<void> connect();
  void dispose();

  Future<void> sendCommand(DriveCommand command, {required int speedPercent});
  Future<void> setMode(DriveMode mode);

  Future<List<TimeSeriesPoint>> fetchHistory(SensorKind kind, {int points = 24});
  Future<List<TimeSeriesPoint>> fetchBatteryHistory({int points = 24});

  Future<(List<TimeSeriesPoint> temperature, List<TimeSeriesPoint> humidity)> fetchTempHumidityHistory({int points = 24});

  /// Live ultrasonic-servo sweep reading, used by the radar preview on
  /// the PIR report page. Each tick is one servo angle (0-180°) plus the
  /// distance echoed back at that angle (cm), null if no echo.
  Stream<RadarSweepReading> get radarStream;

  /// Starts the physical servo sweep + ultrasonic ping loop. Safe to call
  /// repeatedly; a real implementation should no-op if already sweeping.
  Future<void> startRadarSweep();

  /// Stops the sweep and frees the servo for other tasks (matches the
  /// hardware note that GPIO18/servo isn't otherwise reserved).
  Future<void> stopRadarSweep();
}

/// One reading from the ultrasonic-on-servo sweep.
class RadarSweepReading {
  final int angleDegrees; // 0-180
  final double? distanceCm; // null = no echo / out of range
  const RadarSweepReading({required this.angleDegrees, required this.distanceCm});
}

class MockCarConnectionService implements CarConnectionService {
  final _sensorController = StreamController<SensorSnapshot>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _batteryController = StreamController<BatteryStatus>.broadcast();
  final _radarController = StreamController<RadarSweepReading>.broadcast();
  final _random = Random();

  Timer? _tickTimer;
  Timer? _radarTimer;
  SensorSnapshot _last = SensorSnapshot.initial();
  BatteryStatus _lastBattery = BatteryStatus.initial();
  int _radarAngle = 0;
  int _radarDir = 1;

  // A few simulated "obstacles" around the sweep so the radar preview has
  // something to show rather than a flat empty arc.
  final List<(int angle, double distM)> _radarObstacles = const [
    (35, 1.4),
    (95, 2.1),
    (150, 0.9),
  ];

  @override
  Stream<SensorSnapshot> get sensorStream => _sensorController.stream;

  @override
  Stream<bool> get connectionStream => _connectionController.stream;

  @override
  Stream<BatteryStatus> get batteryStream => _batteryController.stream;

  @override
  Stream<RadarSweepReading> get radarStream => _radarController.stream;

  @override
  Future<void> connect() async {
    await Future.delayed(const Duration(milliseconds: 700));
    _connectionController.add(true);

    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(milliseconds: 900), (_) => _tick());
  }

  void _tick() {
    final gas = (_last.gasRaw + _random.nextDouble() * 30 - 15).clamp(0, 1023).toDouble();
    final humidity = (_last.humidity + _random.nextDouble() * 2 - 1).clamp(30, 85).toDouble();
    final temperature = (_last.temperature + _random.nextDouble() * 0.6 - 0.3).clamp(18, 45).toDouble();
    final ultrasonic = (_last.ultrasonicCm + _random.nextDouble() * 40 - 20).clamp(4, 250).toDouble();

    final flame = _random.nextDouble() < 0.01 ? true : (_random.nextDouble() < 0.3 ? false : _last.flameDetected);
    final pir = _random.nextDouble() < 0.05;

    _last = _last.copyWith(
      flameDetected: flame,
      gasRaw: gas,
      pirMotion: pir,
      humidity: humidity,
      temperature: temperature,
      ultrasonicCm: ultrasonic,
    );
    _sensorController.add(_last);

    var pct = _lastBattery.percent;
    var charging = _lastBattery.charging;
    if (!charging && pct <= 14) charging = true;
    if (charging && pct >= 97) charging = false;
    if (charging) {
      pct = (pct + 1.0 + (_random.nextDouble() * 0.1 - 0.05)).clamp(0, 100).toDouble();
    } else {
      // Drain rate tied to RoverPowerModel's representative "average
      // patrol" current draw, converted from mAh/hour to %/tick, so the
      // simulated demo drain is at least in the same ballpark as the
      // real estimate CarState computes on the battery report page —
      // rather than an arbitrary constant.
      final mAhPerTick = RoverPowerModel.representativeDemoMa * (0.9 / 3600); // ~900ms tick, in hours
      final percentPerTick = (mAhPerTick / RoverPowerModel.packCapacityMah) * 100;
      pct = (pct - percentPerTick - (_random.nextDouble() * 0.02)).clamp(0, 100).toDouble();
    }
    final voltage = (6.4 + (pct / 100) * 1.8).clamp(6.4, 8.2).toDouble();
    _lastBattery = _lastBattery.copyWith(
      percent: pct,
      voltage: voltage,
      charging: charging,
    );
    _batteryController.add(_lastBattery);
  }

  @override
  Future<void> sendCommand(DriveCommand command, {required int speedPercent}) async {
    // In production this posts to the ESP32, e.g.:
    // await http.post(Uri.parse('$baseUrl/command'), body: {'cmd': command.name, 'speed': speedPercent});
    await Future.delayed(const Duration(milliseconds: 40));
  }

  @override
  Future<void> setMode(DriveMode mode) async {
    await Future.delayed(const Duration(milliseconds: 40));
  }

  @override
  Future<List<TimeSeriesPoint>> fetchHistory(SensorKind kind, {int points = 24}) async {
    await Future.delayed(const Duration(milliseconds: 350));
    final now = DateTime.now();
    double base;
    double spread;
    switch (kind) {
      case SensorKind.flame:
        base = 0;
        spread = 1;
        break;
      case SensorKind.gas:
        base = 300;
        spread = 220;
        break;
      case SensorKind.pir:
        base = 0;
        spread = 1;
        break;
      case SensorKind.humidityTemp:
        base = 50;
        spread = 15;
        break;
    }
    return List.generate(points, (i) {
      final t = now.subtract(Duration(minutes: (points - i) * 15));
      final v = (base + sin(i / 3) * spread * 0.5 + _random.nextDouble() * spread * 0.5).clamp(0, base + spread * 1.5);
      return TimeSeriesPoint(t, v.toDouble());
    });
  }

  @override
  Future<List<TimeSeriesPoint>> fetchBatteryHistory({int points = 24}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final now = DateTime.now();
    var v = (_lastBattery.percent + 12).clamp(0, 100).toDouble();
    return List.generate(points, (i) {
      final t = now.subtract(Duration(minutes: (points - i) * 15));
      v = (v - 0.5 + _random.nextDouble() * 0.6).clamp(0, 100).toDouble();
      return TimeSeriesPoint(t, v);
    });
  }

  @override
  Future<(List<TimeSeriesPoint>, List<TimeSeriesPoint>)> fetchTempHumidityHistory({int points = 24}) async {
    await Future.delayed(const Duration(milliseconds: 350));
    final now = DateTime.now();
    final temp = List.generate(points, (i) {
      final t = now.subtract(Duration(minutes: (points - i) * 15));
      final v = (27 + sin(i / 3) * 6 + _random.nextDouble() * 3).clamp(15, 48);
      return TimeSeriesPoint(t, v.toDouble());
    });
    final humidity = List.generate(points, (i) {
      final t = now.subtract(Duration(minutes: (points - i) * 15));
      final v = (55 - sin(i / 3) * 12 + _random.nextDouble() * 6).clamp(20, 90);
      return TimeSeriesPoint(t, v.toDouble());
    });
    return (temp, humidity);
  }

  @override
  Future<void> startRadarSweep() async {
    _radarTimer?.cancel();
    _radarAngle = 0;
    _radarDir = 1;
    // In production this drives the servo (GPIO18) across 0-180° while
    // pinging the HC-SR04 (Trig GPIO17 / Echo GPIO16) at each step and
    // streaming {angle, distance} back over the same channel as the
    // other sensor telemetry.
    _radarTimer = Timer.periodic(const Duration(milliseconds: 90), (_) {
      _radarAngle += 6 * _radarDir;
      if (_radarAngle >= 180) {
        _radarAngle = 180;
        _radarDir = -1;
      } else if (_radarAngle <= 0) {
        _radarAngle = 0;
        _radarDir = 1;
      }

      double? distanceCm;
      for (final obstacle in _radarObstacles) {
        if ((obstacle.$1 - _radarAngle).abs() <= 3) {
          distanceCm = obstacle.$2 * 100 + (_random.nextDouble() * 6 - 3);
          break;
        }
      }
      _radarController.add(RadarSweepReading(angleDegrees: _radarAngle, distanceCm: distanceCm));
    });
  }

  @override
  Future<void> stopRadarSweep() async {
    _radarTimer?.cancel();
    _radarTimer = null;
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _radarTimer?.cancel();
    _sensorController.close();
    _connectionController.close();
    _batteryController.close();
    _radarController.close();
  }
}
