import 'package:flutter/foundation.dart';

/// Real sensor ranges and danger/notify thresholds, used to size the
/// half-gauges and to decide when to alert/notify.
///
/// These are placeholders based on each sensor's datasheet range, not a
/// hardware-tested calibration:
///   - Gas (MQ-135, Arduino A0): Arduino's ADC is 10-bit, so the RAW
///     reading is always 0-1023 regardless of gas type/concentration —
///     that part is exact. What's a placeholder is [gasDangerRaw] itself
///     (where "raw" counts as dangerous smoke/gas), since that depends on
///     your specific sensor, ventilation, and what you're detecting.
///   - Temperature / Humidity (DHT11): 0-50°C / 20-90%RH is the sensor's
///     datasheet operating range. [tempDangerC] and [humidityHighPercent]
///     are placeholder "worth a notification" cutoffs.
/// Test each sensor and update the numbers below once you have real
/// readings — nothing else in the app needs to change.
class SensorThresholds {
  SensorThresholds._();

  // --- Gas (MQ-135) — raw 10-bit ADC counts from Arduino A0 ---
  static const double gasMinRaw = 0;
  static const double gasMaxRaw = 1023;
  static const double gasDangerRaw = 650; // placeholder — triggers the flame/gas alarm

  // --- Temperature (DHT11) — °C ---
  static const double tempMinC = 0;
  static const double tempMaxC = 50;
  static const double tempNotifyC = 38; // placeholder — triggers a "high temperature" notification

  // --- Humidity (DHT11) — %RH ---
  static const double humidityMinPercent = 0;
  static const double humidityMaxPercent = 100;
  static const double humidityNotifyPercent = 75; // placeholder — triggers a "high humidity" notification
}

enum DriveMode { manual, auto }

enum DriveCommand { forward, backward, left, right, stop }

enum AlertSeverity { none, warning, danger }

enum AlertSource { none, ultrasonic, flame, gas, pir }

@immutable
class AlertEvent {
  final AlertSource source;
  final AlertSeverity severity;
  final String message;
  final DateTime timestamp;

  const AlertEvent({
    required this.source,
    required this.severity,
    required this.message,
    required this.timestamp,
  });

  static AlertEvent none() => AlertEvent(
        source: AlertSource.none,
        severity: AlertSeverity.none,
        message: '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(0),
      );

  bool get isActive => severity != AlertSeverity.none;
}

/// Snapshot of every sensor reading coming off the ESP32/Arduino stack.
@immutable
class SensorSnapshot {
  final bool flameDetected;
  final double gasRaw; // raw 10-bit ADC counts from MQ-135 (Arduino A0), 0-1023
  final bool pirMotion;
  final double humidity; // %RH (DHT11)
  final double temperature; // Celsius (DHT11)
  final double ultrasonicCm; // distance to nearest obstacle (HC-SR04, on servo)

  const SensorSnapshot({
    required this.flameDetected,
    required this.gasRaw,
    required this.pirMotion,
    required this.humidity,
    required this.temperature,
    required this.ultrasonicCm,
  });

  factory SensorSnapshot.initial() => const SensorSnapshot(
        flameDetected: false,
        gasRaw: 280,
        pirMotion: false,
        humidity: 48,
        temperature: 27.5,
        ultrasonicCm: 180,
      );

  SensorSnapshot copyWith({
    bool? flameDetected,
    double? gasRaw,
    bool? pirMotion,
    double? humidity,
    double? temperature,
    double? ultrasonicCm,
  }) {
    return SensorSnapshot(
      flameDetected: flameDetected ?? this.flameDetected,
      gasRaw: gasRaw ?? this.gasRaw,
      pirMotion: pirMotion ?? this.pirMotion,
      humidity: humidity ?? this.humidity,
      temperature: temperature ?? this.temperature,
      ultrasonicCm: ultrasonicCm ?? this.ultrasonicCm,
    );
  }
}

/// Battery telemetry for the 4-DC-motor drive pack.
@immutable
class BatteryStatus {
  final double percent; // 0..100
  final double voltage; // pack volts
  final bool charging;
  final double estimatedMinutesRemaining;

  const BatteryStatus({
    required this.percent,
    required this.voltage,
    required this.charging,
    required this.estimatedMinutesRemaining,
  });

  factory BatteryStatus.initial() => const BatteryStatus(
        percent: 100,
        voltage: 8.2,
        charging: false,
        estimatedMinutesRemaining: 0,
      );

  BatteryStatus copyWith({
    double? percent,
    double? voltage,
    bool? charging,
    double? estimatedMinutesRemaining,
  }) {
    return BatteryStatus(
      percent: percent ?? this.percent,
      voltage: voltage ?? this.voltage,
      charging: charging ?? this.charging,
      estimatedMinutesRemaining: estimatedMinutesRemaining ?? this.estimatedMinutesRemaining,
    );
  }
}

enum NavPhase { idle, driving, obstacleStop, reversing, scanningRight, scanningLeft, escaping }

@immutable
class CarStatus {
  final DriveMode mode;
  final NavPhase phase;
  final int speedPercent; // 0-100, moderate ~55, max 100
  final bool connected;

  const CarStatus({
    required this.mode,
    required this.phase,
    required this.speedPercent,
    required this.connected,
  });

  factory CarStatus.initial() => const CarStatus(
        mode: DriveMode.manual,
        phase: NavPhase.idle,
        speedPercent: 0,
        connected: false,
      );

  CarStatus copyWith({
    DriveMode? mode,
    NavPhase? phase,
    int? speedPercent,
    bool? connected,
  }) {
    return CarStatus(
      mode: mode ?? this.mode,
      phase: phase ?? this.phase,
      speedPercent: speedPercent ?? this.speedPercent,
      connected: connected ?? this.connected,
    );
  }
}

/// One point in a historical time series, used on the report pages.
@immutable
class TimeSeriesPoint {
  final DateTime time;
  final double value;
  const TimeSeriesPoint(this.time, this.value);
}

/// State of the phone <-> ESP32 WebSocket link, surfaced in the
/// connection panel.
enum EspLinkState { demo, connecting, connected, reconnecting, disconnected, error }

enum SensorKind { flame, gas, pir, humidityTemp }

extension SensorKindMeta on SensorKind {
  String get label {
    switch (this) {
      case SensorKind.flame:
        return 'Flame';
      case SensorKind.gas:
        return 'Gas';
      case SensorKind.pir:
        return 'PIR Motion';
      case SensorKind.humidityTemp:
        return 'Humidity & Temp';
    }
  }

  String get unit {
    switch (this) {
      case SensorKind.flame:
        return '';
      case SensorKind.gas:
        return 'raw';
      case SensorKind.pir:
        return '';
      case SensorKind.humidityTemp:
        return '%RH / °C';
    }
  }
}
