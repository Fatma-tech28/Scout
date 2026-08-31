/// Estimated rover battery runtime, derived from typical component
/// current draw rather than a made-up decay curve.
///
/// The pack itself (7.4V nominal, 6.4-8.2V range — matches the voltage
/// already shown on the battery report page) is assumed to be a 2S
/// Li-ion/LiPo. [packCapacityMah] and every current-draw constant below
/// are placeholders based on typical datasheet figures for these parts,
/// not a measurement of your specific build — update them once you've
/// measured your actual pack capacity and, ideally, actual current draw
/// (a cheap USB/inline power meter on the 5V rail + a clamp meter or
/// shunt on the motor supply will get you real numbers).
class RoverPowerModel {
  RoverPowerModel._();

  // --- Pack ---
  static const double packCapacityMah = 2200;

  // --- Always-on electronics (mA) ---
  static const double esp32Ma = 180; // WiFi active, typical for most dev boards
  static const double arduinoUnoMa = 50;
  static const double mq135Ma = 150; // MQ-135's internal heater dominates its draw
  static const double dht11Ma = 1.5;
  static const double flameSensorEachMa = 1; // x2 (left + right)
  static const double pirMa = 0.05; // HC-SR505 idle draw
  static const double hcSr04Ma = 15;
  static const double l298nOverheadMa = 36; // driver logic/quiescent, excludes motor current itself

  static const double _alwaysOnMa =
      esp32Ma + arduinoUnoMa + mq135Ma + dht11Ma + (flameSensorEachMa * 2) + pirMa + hcSr04Ma + l298nOverheadMa;

  // --- Servo (radar sweep) ---
  static const double servoIdleMa = 10;
  static const double servoActiveMa = 200; // while sweeping

  // --- Drive motors ---
  // Current is modeled as scaling roughly linearly with commanded speed
  // between a light-load floor and a near-stall ceiling. Real current
  // depends heavily on load/terrain/friction, so treat this as an
  // estimate, not a measurement.
  static const double motorMinMovingMa = 150; // per motor, light load at low speed
  static const double motorMaxMa = 700; // per motor, near-stall/full load
  static const int motorCount = 4;

  /// Estimated total pack current draw (mA) right now, given the
  /// current commanded drive speed (0 if stopped) and whether the radar
  /// servo is actively sweeping.
  static double totalCurrentMa({required int speedPercent, required bool radarActive}) {
    final motors = speedPercent <= 0
        ? 0.0
        : motorCount * (motorMinMovingMa + (motorMaxMa - motorMinMovingMa) * (speedPercent.clamp(0, 100) / 100));
    final servo = radarActive ? servoActiveMa : servoIdleMa;
    return _alwaysOnMa + servo + motors;
  }

  /// A representative "average patrol" draw — some driving, some
  /// stopped/scanning, radar off — used to simulate a believable demo
  /// battery drain when there's no real hardware reporting actual draw.
  static double get representativeDemoMa => totalCurrentMa(speedPercent: 35, radarActive: false);

  /// "Time to empty" at the current draw rate, in minutes, given the
  /// battery's remaining percent. Returns null when there's no draw to
  /// divide by (e.g. fully stopped with everything else at zero, which
  /// shouldn't happen in practice since the always-on electronics alone
  /// draw current).
  static double? minutesRemaining({required double batteryPercent, required double currentMa}) {
    if (currentMa <= 0) return null;
    final remainingMah = (batteryPercent.clamp(0, 100) / 100) * packCapacityMah;
    return (remainingMah / currentMa) * 60;
  }
}
