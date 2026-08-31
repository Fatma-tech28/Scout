import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/power_model.dart';
import '../models/sensor_data.dart';
import '../services/car_connection_service.dart';
import '../services/voice_alert_service.dart';
import '../services/websocket_car_connection_service.dart';

/// Drives all control-page and dashboard behavior: manual press-to-move
/// controls, an autonomous driving loop, the ultrasonic stop/reverse/scan
/// routine, the flame/gas-triggered alarm (voice + full-screen, mutable),
/// lightweight notifications for PIR/temperature/humidity, adjustable
/// drive speed for both modes, the PIR-page radar sweep preview, and the
/// ESP32 WebSocket connection lifecycle.
class CarState extends ChangeNotifier {
  CarState(CarConnectionService initialService) : _service = initialService {
    _bindService();
  }

  CarConnectionService _service;
  final VoiceAlertService _voice = VoiceAlertService();

  static const int moderateSpeed = 55;
  static const int maxSpeed = 100;
  static const int minAdjustableSpeed = 15;
  static const double obstacleThresholdCm = 18;
  static const double clearThresholdCm = 35;

  CarStatus _status = CarStatus.initial();
  SensorSnapshot _sensors = SensorSnapshot.initial();
  SensorSnapshot? _previousSensors;
  BatteryStatus _battery = BatteryStatus.initial();
  DriveCommand? _heldCommand;
  bool _sequenceBusy = false;
  bool _flameEscapeActive = false;

  // --- ESP32 connection ---
  // `_usingRealEsp` tracks which *kind* of service is active, separate
  // from `_linkState` (which tracks the connection's current status).
  // Without this split, the connectionStream's `true` event looked
  // identical whether it came from the real WebSocket service or the
  // local demo simulator — which caused the connection panel to show
  // "Connected to null" while in demo mode instead of "Demo mode".
  bool _usingRealEsp = false;
  EspLinkState _linkState = EspLinkState.demo;
  String? _espHost;
  bool get isDemoMode => !_usingRealEsp;

  // --- Speed control ---
  int _manualSpeedPercent = moderateSpeed;
  int _autoMaxSpeedPercent = 70;

  // --- Radar sweep (PIR report page preview) ---
  bool _radarActive = false;
  RadarSweepReading? _radarReading;
  StreamSubscription<RadarSweepReading>? _radarSub;

  // --- Alerts ---
  // `_alert` drives the status-header chip (any source, including the
  // ultrasonic obstacle routine). `_criticalActive` additionally drives
  // the full-screen overlay + voice alarm, and is only ever set by flame
  // or gas — per the brief, PIR/temperature/humidity never alarm, and
  // the ultrasonic routine's warning stays a small chip, not a takeover.
  AlertEvent _alert = AlertEvent.none();
  bool _criticalActive = false;
  bool _alertsEnabled = true;
  Timer? _voiceRepeatTimer;

  // --- Notifications (PIR / high temp / high humidity) ---
  final _notificationsController = StreamController<String>.broadcast();

  StreamSubscription<SensorSnapshot>? _sensorSub;
  StreamSubscription<BatteryStatus>? _batterySub;
  StreamSubscription<bool>? _connSub;
  Timer? _autoDriveTimer;
  Timer? _sequenceTimer;
  Timer? _flameTimer;

  CarStatus get status => _status;
  SensorSnapshot get sensors => _sensors;
  BatteryStatus get battery => _battery;
  AlertEvent get alert => _alert;
  bool get alertActive => _alert.isActive;
  bool get criticalAlertActive => _criticalActive;
  bool get alertsEnabled => _alertsEnabled;
  DriveCommand? get heldCommand => _heldCommand;
  bool get connecting => _linkState == EspLinkState.connecting;
  EspLinkState get linkState => _linkState;
  String? get espHost => _espHost;

  int get manualSpeedPercent => _manualSpeedPercent;
  int get autoMaxSpeedPercent => _autoMaxSpeedPercent;

  bool get radarActive => _radarActive;
  RadarSweepReading? get radarReading => _radarReading;

  Stream<String> get notifications => _notificationsController.stream;

  /// Estimated runtime left at the *current* draw rate — component
  /// power draw (motors at the current speed, servo, always-on
  /// electronics) divided into the pack's remaining capacity. See
  /// RoverPowerModel for the assumptions behind this number. Null while
  /// charging, since "time to empty" doesn't apply.
  double? get estimatedMinutesRemaining {
    if (_battery.charging) return null;
    final drivingSpeed = (_status.phase == NavPhase.driving ||
            _status.phase == NavPhase.reversing ||
            _status.phase == NavPhase.escaping)
        ? _status.speedPercent
        : 0;
    final currentMa = RoverPowerModel.totalCurrentMa(speedPercent: drivingSpeed, radarActive: _radarActive);
    return RoverPowerModel.minutesRemaining(batteryPercent: _battery.percent, currentMa: currentMa);
  }

  Future<void> init() async {
    await _service.connect();
  }

  void _bindService() {
    _connSub?.cancel();
    _sensorSub?.cancel();
    _batterySub?.cancel();
    _connSub = _service.connectionStream.listen((connected) {
      if (!_usingRealEsp) {
        // The local simulator is always "connected" from the app's
        // perspective — it's not a real link, so it never shows the
        // rover's host or a connecting/reconnecting state.
        _linkState = EspLinkState.demo;
        _status = _status.copyWith(connected: connected);
        notifyListeners();
        return;
      }
      if (connected) {
        _linkState = EspLinkState.connected;
        _status = _status.copyWith(connected: true);
      } else {
        _linkState = EspLinkState.reconnecting;
        _status = _status.copyWith(connected: false);
      }
      notifyListeners();
    });
    _sensorSub = _service.sensorStream.listen(_onSensorUpdate);
    _batterySub = _service.batteryStream.listen((b) {
      _battery = b;
      notifyListeners();
    });
  }

  // ---------------------------------------------------------------------
  // ESP32 connection management
  // ---------------------------------------------------------------------
  /// Connects to a real rover at [host] (e.g. "192.168.4.1"), replacing
  /// whatever service (demo or a previous rover) was active.
  Future<void> connectToEsp(String host, {int port = 81}) async {
    _espHost = host;
    _usingRealEsp = true;
    _linkState = EspLinkState.connecting;
    _status = _status.copyWith(connected: false);
    notifyListeners();

    await _teardownCurrentService();
    _service = WebSocketCarConnectionService(host: host, port: port);
    _bindService();
    try {
      await _service.connect();
    } catch (_) {
      _linkState = EspLinkState.error;
      notifyListeners();
    }
  }

  /// Switches back to the local simulator — handy for trying the app
  /// with no rover on hand.
  Future<void> useDemoMode() async {
    _espHost = null;
    _usingRealEsp = false;
    await _teardownCurrentService();
    _service = MockCarConnectionService();
    _linkState = EspLinkState.demo;
    _bindService();
    await _service.connect();
  }

  Future<void> _teardownCurrentService() async {
    _autoDriveTimer?.cancel();
    _sequenceTimer?.cancel();
    _flameTimer?.cancel();
    _radarSub?.cancel();
    _radarSub = null;
    _radarActive = false;
    _radarReading = null;
    _service.dispose();
  }

  // ---------------------------------------------------------------------
  // Speed control
  // ---------------------------------------------------------------------
  void setManualSpeed(int percent) {
    final clamped = percent.clamp(minAdjustableSpeed, maxSpeed);
    if (clamped == _manualSpeedPercent) return;
    _manualSpeedPercent = clamped;
    if (_heldCommand != null && !_sequenceBusy && !_flameEscapeActive) {
      _status = _status.copyWith(speedPercent: _manualSpeedPercent);
      _service.sendCommand(_heldCommand!, speedPercent: _manualSpeedPercent);
    }
    notifyListeners();
  }

  void setAutoMaxSpeed(int percent) {
    final clamped = percent.clamp(minAdjustableSpeed, maxSpeed);
    if (clamped == _autoMaxSpeedPercent) return;
    _autoMaxSpeedPercent = clamped;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Mode switching
  // ---------------------------------------------------------------------
  Future<void> setMode(DriveMode mode) async {
    if (_status.mode == mode) return;
    _heldCommand = null;
    _sequenceBusy = false;
    _autoDriveTimer?.cancel();
    _sequenceTimer?.cancel();
    _status = _status.copyWith(mode: mode, phase: NavPhase.idle, speedPercent: 0);
    notifyListeners();
    await _service.setMode(mode);
    await _service.sendCommand(DriveCommand.stop, speedPercent: 0);
    if (mode == DriveMode.auto) {
      _startAutoLoop();
    }
  }

  // ---------------------------------------------------------------------
  // Manual mode: press-and-hold controls
  // ---------------------------------------------------------------------
  void pressCommand(DriveCommand cmd) {
    if (_status.mode != DriveMode.manual) return;
    if (_sequenceBusy || _flameEscapeActive) return;

    HapticFeedback.selectionClick();
    _heldCommand = cmd;
    _status = _status.copyWith(phase: NavPhase.driving, speedPercent: _manualSpeedPercent);
    notifyListeners();
    _service.sendCommand(cmd, speedPercent: _manualSpeedPercent);
  }

  void releaseCommand() {
    if (_status.mode != DriveMode.manual) return;
    _heldCommand = null;
    if (!_sequenceBusy && !_flameEscapeActive) {
      _status = _status.copyWith(phase: NavPhase.idle, speedPercent: 0);
      notifyListeners();
      _service.sendCommand(DriveCommand.stop, speedPercent: 0);
    }
  }

  // ---------------------------------------------------------------------
  // Auto mode: continuous driving loop, capped at the operator's chosen
  // max auto speed rather than a fixed constant.
  // ---------------------------------------------------------------------
  void _startAutoLoop() {
    _autoDriveTimer?.cancel();
    _autoDriveTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (_status.mode != DriveMode.auto) return;
      if (_sequenceBusy || _flameEscapeActive) return;
      _status = _status.copyWith(phase: NavPhase.driving, speedPercent: _autoMaxSpeedPercent);
      _service.sendCommand(DriveCommand.forward, speedPercent: _autoMaxSpeedPercent);
      notifyListeners();
    });
  }

  // ---------------------------------------------------------------------
  // Sensor stream handling
  // ---------------------------------------------------------------------
  void _onSensorUpdate(SensorSnapshot snap) {
    final prev = _previousSensors;
    _previousSensors = _sensors;
    _sensors = snap;

    // --- Critical alarm sources: flame and dangerous gas only ---
    if (snap.flameDetected && !_criticalActive) {
      _raiseCriticalAlert(AlertSource.flame, 'Warning. Flame detected.');
      if (!_flameEscapeActive) _handleFlame();
    }
    if (snap.gasRaw >= SensorThresholds.gasDangerRaw && !_criticalActive) {
      _raiseCriticalAlert(AlertSource.gas, 'Warning. Gas levels critical.');
    }

    // --- Lightweight notifications: PIR / high temp / high humidity ---
    // Edge-triggered off the previous reading so these fire once per
    // event instead of spamming every tick the condition stays true.
    if (prev != null) {
      if (snap.pirMotion && !prev.pirMotion) {
        _pushNotification('Motion detected nearby.');
      }
      if (snap.temperature >= SensorThresholds.tempNotifyC && prev.temperature < SensorThresholds.tempNotifyC) {
        _pushNotification('High temperature: ${snap.temperature.toStringAsFixed(0)}°C.');
      }
      if (snap.humidity >= SensorThresholds.humidityNotifyPercent && prev.humidity < SensorThresholds.humidityNotifyPercent) {
        _pushNotification('High humidity: ${snap.humidity.toStringAsFixed(0)}%.');
      }
    }

    // --- Ultrasonic obstacle routine (unchanged; header chip only) ---
    final drivingForward = _status.phase == NavPhase.driving &&
        (_status.mode == DriveMode.auto || _heldCommand == DriveCommand.forward);

    if (!_flameEscapeActive && !_sequenceBusy && drivingForward && snap.ultrasonicCm <= obstacleThresholdCm) {
      _runObstacleSequence();
    }

    notifyListeners();
  }

  /// Flame sensor safety behavior: reverse at maximum speed and escape.
  /// This is a safety override and always uses [maxSpeed] regardless of
  /// the operator's chosen auto-speed cap.
  void _handleFlame() {
    _flameEscapeActive = true;
    _sequenceTimer?.cancel();

    if (_status.mode == DriveMode.auto) {
      _status = _status.copyWith(phase: NavPhase.escaping, speedPercent: maxSpeed);
      _service.sendCommand(DriveCommand.backward, speedPercent: maxSpeed);
      notifyListeners();

      _flameTimer?.cancel();
      _flameTimer = Timer(const Duration(seconds: 3), () {
        _flameEscapeActive = false;
        if (_status.mode == DriveMode.auto) {
          _status = _status.copyWith(phase: NavPhase.driving, speedPercent: _autoMaxSpeedPercent);
        } else {
          _status = _status.copyWith(phase: NavPhase.idle, speedPercent: 0);
        }
        notifyListeners();
      });
    } else {
      _flameEscapeActive = false;
    }
  }

  /// Ultrasonic safety routine, active at 100% capability in both modes:
  /// stop -> reverse two steps -> servo scan right -> proceed if clear, else
  /// scan left -> proceed if clear, else remain stopped and alert.
  /// This only ever raises the header-chip warning, never the full
  /// critical alarm — obstacles are routine, not an emergency.
  void _runObstacleSequence() {
    _sequenceBusy = true;
    _alert = AlertEvent(
      source: AlertSource.ultrasonic,
      severity: AlertSeverity.warning,
      message: 'Obstacle detected ahead. Reversing and scanning.',
      timestamp: DateTime.now(),
    );

    final reverseSpeed = _status.mode == DriveMode.auto ? _autoMaxSpeedPercent : _manualSpeedPercent;

    _status = _status.copyWith(phase: NavPhase.obstacleStop, speedPercent: 0);
    _service.sendCommand(DriveCommand.stop, speedPercent: 0);
    notifyListeners();

    _sequenceTimer = Timer(const Duration(milliseconds: 500), () {
      _status = _status.copyWith(phase: NavPhase.reversing, speedPercent: reverseSpeed);
      _service.sendCommand(DriveCommand.backward, speedPercent: reverseSpeed);
      notifyListeners();

      _sequenceTimer = Timer(const Duration(milliseconds: 900), () {
        _service.sendCommand(DriveCommand.stop, speedPercent: 0);
        _status = _status.copyWith(phase: NavPhase.scanningRight, speedPercent: 0);
        notifyListeners();

        _sequenceTimer = Timer(const Duration(milliseconds: 800), () {
          final rightClear = _sensors.ultrasonicCm > clearThresholdCm;
          if (rightClear) {
            _resumeAfterScan();
          } else {
            _status = _status.copyWith(phase: NavPhase.scanningLeft);
            notifyListeners();
            _sequenceTimer = Timer(const Duration(milliseconds: 800), _resumeAfterScan);
          }
        });
      });
    });
  }

  void _resumeAfterScan() {
    _sequenceBusy = false;
    final auto = _status.mode == DriveMode.auto;
    final resumeSpeed = auto ? _autoMaxSpeedPercent : _manualSpeedPercent;
    _status = _status.copyWith(
      phase: auto ? NavPhase.driving : NavPhase.idle,
      speedPercent: auto ? resumeSpeed : 0,
    );
    if (auto) {
      _service.sendCommand(DriveCommand.forward, speedPercent: resumeSpeed);
    } else {
      _service.sendCommand(DriveCommand.stop, speedPercent: 0);
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Critical alarm system (flame + gas only): full-screen overlay, voice,
  // and a global mute that silences it completely until re-enabled.
  // ---------------------------------------------------------------------
  void _raiseCriticalAlert(AlertSource source, String message) {
    _alert = AlertEvent(source: source, severity: AlertSeverity.danger, message: message, timestamp: DateTime.now());
    if (!_alertsEnabled) return; // muted: track internally, don't alarm

    _criticalActive = true;
    HapticFeedback.heavyImpact();
    _voice.speak(message);
    _voiceRepeatTimer?.cancel();
    _voiceRepeatTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_criticalActive && _alertsEnabled) _voice.speak(message);
    });
  }

  void _pushNotification(String message) {
    if (!_notificationsController.isClosed) {
      _notificationsController.add(message);
    }
  }

  /// Manually fires the same critical-alarm path flame/gas would —
  /// useful for confirming the voice alarm actually plays on your
  /// device/setup without waiting for the demo simulator to randomly
  /// trip flame or gas. Only meant for demo mode.
  void triggerTestAlarm() {
    if (_criticalActive) return;
    _raiseCriticalAlert(AlertSource.flame, 'This is a test of the alarm system.');
  }

  /// "Stop Alert" — dismisses the current alarm/chip. Does not by itself
  /// resume motion; the underlying safety sequence (if any) continues.
  void dismissAlert() {
    _alert = AlertEvent.none();
    _criticalActive = false;
    _voiceRepeatTimer?.cancel();
    _voice.stop();
    notifyListeners();
  }

  /// Global alarm mute. Turning it off immediately silences any active
  /// alarm (voice + overlay) and suppresses new flame/gas alarms until
  /// turned back on — sensor readings themselves are unaffected.
  void setAlertsEnabled(bool enabled) {
    if (enabled == _alertsEnabled) return;
    _alertsEnabled = enabled;
    if (!enabled) {
      _criticalActive = false;
      _voiceRepeatTimer?.cancel();
      _voice.stop();
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Radar sweep preview (PIR report page)
  // ---------------------------------------------------------------------
  Future<void> setRadarActive(bool active) async {
    if (active == _radarActive) return;
    _radarActive = active;
    if (active) {
      _radarReading = null;
      _radarSub?.cancel();
      _radarSub = _service.radarStream.listen((reading) {
        _radarReading = reading;
        notifyListeners();
      });
      await _service.startRadarSweep();
    } else {
      await _service.stopRadarSweep();
      await _radarSub?.cancel();
      _radarSub = null;
      _radarReading = null;
    }
    notifyListeners();
  }

  void stopRadarIfActive() {
    if (!_radarActive) return;
    setRadarActive(false);
  }

  Future<List<TimeSeriesPoint>> history(SensorKind kind) => _service.fetchHistory(kind);

  Future<List<TimeSeriesPoint>> batteryHistory() => _service.fetchBatteryHistory();

  Future<(List<TimeSeriesPoint>, List<TimeSeriesPoint>)> tempHumidityHistory() =>
      _service.fetchTempHumidityHistory();

  @override
  void dispose() {
    _sensorSub?.cancel();
    _batterySub?.cancel();
    _connSub?.cancel();
    _radarSub?.cancel();
    _autoDriveTimer?.cancel();
    _sequenceTimer?.cancel();
    _flameTimer?.cancel();
    _voiceRepeatTimer?.cancel();
    _notificationsController.close();
    _service.dispose();
    super.dispose();
  }
}
