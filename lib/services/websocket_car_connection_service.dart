import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/sensor_data.dart';
import 'car_connection_service.dart';

/// Real transport to the ESP32 over a single WebSocket connection.
///
/// --- Wire protocol (JSON, one object per WebSocket text frame) ---
///
/// ESP32 -> phone:
///   {"type":"sensor","flame":bool,"gasRaw":num,"pir":bool,
///    "humidity":num,"temperature":num,"ultrasonicCm":num}
///   {"type":"battery","percent":num,"voltage":num,"charging":bool,"etaMin":num}
///   {"type":"radar","angle":int,"distanceCm":num|null}
///   {"type":"history","reqId":str,"points":[{"t":epochMillis,"v":num}, ...]}
///   {"type":"historyDual","reqId":str,"points":[{"t":epochMillis,"temp":num,"hum":num}, ...]}
///
/// Phone -> ESP32:
///   {"type":"command","cmd":"forward"|"backward"|"left"|"right"|"stop","speed":int}
///   {"type":"mode","mode":"manual"|"auto"}
///   {"type":"radar","active":bool}
///   {"type":"historyRequest","reqId":str,"kind":"flame"|"gas"|"pir"|"humidityTemp","points":int}
///   {"type":"batteryHistoryRequest","reqId":str,"points":int}
///
/// This class only handles the phone side. The ESP32 firmware needs to
/// speak the same protocol — see the project notes for the matching
/// `.ino` implementation once it's written.
class WebSocketCarConnectionService implements CarConnectionService {
  WebSocketCarConnectionService({required this.host, this.port = 81, this.path = '/ws'});

  final String host;
  final int port;
  final String path;

  WebSocketChannel? _channel;
  StreamSubscription? _channelSub;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  bool _manuallyClosed = false;
  int _reconnectAttempt = 0;

  final _sensorController = StreamController<SensorSnapshot>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _batteryController = StreamController<BatteryStatus>.broadcast();
  final _radarController = StreamController<RadarSweepReading>.broadcast();

  final Map<String, Completer<dynamic>> _pendingRequests = {};
  final _random = Random();

  SensorSnapshot _lastSensors = SensorSnapshot.initial();

  Uri get _uri => Uri.parse('ws://$host:$port$path');

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
    _manuallyClosed = false;
    _reconnectAttempt = 0;
    await _openSocket();
  }

  Future<void> _openSocket() async {
    _channelSub?.cancel();
    _channel?.sink.close();
    try {
      final channel = WebSocketChannel.connect(_uri);
      _channel = channel;
      // WebSocketChannel.connect doesn't await the handshake itself;
      // `ready` completes once the connection is actually established
      // (or throws if it fails), so callers awaiting connect() get an
      // accurate result instead of a false "connected".
      await channel.ready;

      _reconnectAttempt = 0;
      _connectionController.add(true);

      _channelSub = channel.stream.listen(
        _handleMessage,
        onError: (_) => _handleDisconnect(),
        onDone: _handleDisconnect,
        cancelOnError: true,
      );

      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        _send({'type': 'ping'});
      });
    } catch (_) {
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _connectionController.add(false);
    _heartbeatTimer?.cancel();
    if (_manuallyClosed) return;
    // Exponential-ish backoff, capped at 10s, so a rover that's briefly
    // out of WiFi range reconnects on its own without hammering it.
    _reconnectAttempt += 1;
    final delaySeconds = min(10, 1 + _reconnectAttempt * 2);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), _openSocket);
  }

  void _handleMessage(dynamic raw) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    switch (msg['type']) {
      case 'sensor':
        _lastSensors = SensorSnapshot(
          flameDetected: msg['flame'] == true,
          gasRaw: (msg['gasRaw'] as num?)?.toDouble() ?? _lastSensors.gasRaw,
          pirMotion: msg['pir'] == true,
          humidity: (msg['humidity'] as num?)?.toDouble() ?? _lastSensors.humidity,
          temperature: (msg['temperature'] as num?)?.toDouble() ?? _lastSensors.temperature,
          ultrasonicCm: (msg['ultrasonicCm'] as num?)?.toDouble() ?? _lastSensors.ultrasonicCm,
        );
        _sensorController.add(_lastSensors);
        break;
      case 'battery':
        _batteryController.add(BatteryStatus(
          percent: (msg['percent'] as num?)?.toDouble() ?? 0,
          voltage: (msg['voltage'] as num?)?.toDouble() ?? 0,
          charging: msg['charging'] == true,
          estimatedMinutesRemaining: (msg['etaMin'] as num?)?.toDouble() ?? 0,
        ));
        break;
      case 'radar':
        _radarController.add(RadarSweepReading(
          angleDegrees: (msg['angle'] as num?)?.toInt() ?? 0,
          distanceCm: (msg['distanceCm'] as num?)?.toDouble(),
        ));
        break;
      case 'history':
      case 'historyDual':
        final reqId = msg['reqId'] as String?;
        final completer = reqId != null ? _pendingRequests.remove(reqId) : null;
        completer?.complete(msg['points']);
        break;
      default:
        break;
    }
  }

  void _send(Map<String, dynamic> msg) {
    final channel = _channel;
    if (channel == null) return;
    try {
      channel.sink.add(jsonEncode(msg));
    } catch (_) {
      // Socket likely dropped between checks; the stream's onError/onDone
      // handler will pick up the disconnect and trigger a reconnect.
    }
  }

  String _newReqId() => '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(9999)}';

  Future<dynamic> _request(Map<String, dynamic> msg, {Duration timeout = const Duration(seconds: 5)}) {
    final reqId = _newReqId();
    final completer = Completer<dynamic>();
    _pendingRequests[reqId] = completer;
    _send({...msg, 'reqId': reqId});
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _pendingRequests.remove(reqId);
        return <dynamic>[];
      },
    );
  }

  @override
  Future<void> sendCommand(DriveCommand command, {required int speedPercent}) async {
    _send({'type': 'command', 'cmd': command.name, 'speed': speedPercent});
  }

  @override
  Future<void> setMode(DriveMode mode) async {
    _send({'type': 'mode', 'mode': mode.name});
  }

  @override
  Future<void> startRadarSweep() async {
    _send({'type': 'radar', 'active': true});
  }

  @override
  Future<void> stopRadarSweep() async {
    _send({'type': 'radar', 'active': false});
  }

  @override
  Future<List<TimeSeriesPoint>> fetchHistory(SensorKind kind, {int points = 24}) async {
    final raw = await _request({'type': 'historyRequest', 'kind': kind.name, 'points': points});
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => TimeSeriesPoint(
              DateTime.fromMillisecondsSinceEpoch((e['t'] as num).toInt()),
              (e['v'] as num).toDouble(),
            ))
        .toList();
  }

  @override
  Future<List<TimeSeriesPoint>> fetchBatteryHistory({int points = 24}) async {
    final raw = await _request({'type': 'batteryHistoryRequest', 'points': points});
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => TimeSeriesPoint(
              DateTime.fromMillisecondsSinceEpoch((e['t'] as num).toInt()),
              (e['v'] as num).toDouble(),
            ))
        .toList();
  }

  @override
  Future<(List<TimeSeriesPoint>, List<TimeSeriesPoint>)> fetchTempHumidityHistory({int points = 24}) async {
    final raw = await _request({'type': 'historyRequest', 'kind': 'humidityTemp', 'points': points});
    if (raw is! List) return (<TimeSeriesPoint>[], <TimeSeriesPoint>[]);
    final temp = <TimeSeriesPoint>[];
    final hum = <TimeSeriesPoint>[];
    for (final e in raw.whereType<Map>()) {
      final t = DateTime.fromMillisecondsSinceEpoch((e['t'] as num).toInt());
      temp.add(TimeSeriesPoint(t, (e['temp'] as num).toDouble()));
      hum.add(TimeSeriesPoint(t, (e['hum'] as num).toDouble()));
    }
    return (temp, hum);
  }

  @override
  void dispose() {
    _manuallyClosed = true;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _channelSub?.cancel();
    _channel?.sink.close();
    _sensorController.close();
    _connectionController.close();
    _batteryController.close();
    _radarController.close();
  }
}
