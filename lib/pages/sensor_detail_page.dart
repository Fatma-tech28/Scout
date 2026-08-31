import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sensor_data.dart';
import '../state/car_state.dart';
import '../theme/app_theme.dart';
import '../widgets/dual_trend_chart.dart';
import '../widgets/event_bar_chart.dart';
import '../widgets/half_gauge_painter.dart';
import '../widgets/radar_sweep_card.dart';
import '../widgets/time_series_analysis_card.dart';
import '../widgets/trend_chart.dart';

class SensorDetailPage extends StatefulWidget {
  final SensorKind kind;
  const SensorDetailPage({super.key, required this.kind});

  @override
  State<SensorDetailPage> createState() => _SensorDetailPageState();
}

class _SensorDetailPageState extends State<SensorDetailPage> {
  // Single-series history (flame / gas / pir).
  late Future<List<TimeSeriesPoint>> _future;
  // Dual-series history, only used for humidity+temp.
  Future<(List<TimeSeriesPoint>, List<TimeSeriesPoint>)>? _dualFuture;

  bool get _isEvent => widget.kind == SensorKind.flame || widget.kind == SensorKind.pir;
  bool get _isDual => widget.kind == SensorKind.humidityTemp;
  bool get _isPir => widget.kind == SensorKind.pir;

  @override
  void initState() {
    super.initState();
    if (_isDual) {
      _dualFuture = context.read<CarState>().tempHumidityHistory();
      _future = Future.value(const []);
    } else {
      _future = context.read<CarState>().history(widget.kind);
    }
  }

  @override
  void dispose() {
    // The radar sweep drives a physical servo — don't leave it running
    // once the operator navigates away from the PIR report page.
    if (_isPir) {
      context.read<CarState>().stopRadarIfActive();
    }
    super.dispose();
  }

  void _retry() {
    setState(() {
      if (_isDual) {
        _dualFuture = context.read<CarState>().tempHumidityHistory();
      } else {
        _future = context.read<CarState>().history(widget.kind);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.kind.label} report')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryGauges(kind: widget.kind),
              if (_isPir) ...[
                const SizedBox(height: 16),
                const RadarSweepCard(),
              ],
              const SizedBox(height: 18),
              _buildChartSection(context),
              const SizedBox(height: 18),
              Text(
                'About this sensor',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                _description(widget.kind),
                style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loadingBox() => Container(
        height: 260,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.blue50, borderRadius: BorderRadius.circular(24)),
        child: const CircularProgressIndicator(color: AppColors.blue400),
      );

  Widget _errorBox() => Container(
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.blue50, borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.danger),
            const SizedBox(height: 8),
            const Text('Could not load history', style: TextStyle(color: AppColors.textSecondary)),
            TextButton(onPressed: _retry, child: const Text('Retry')),
          ],
        ),
      );

  // Chart type is chosen to suit the sensor: binary/event sensors get a
  // bar chart, the single continuous gas reading gets a line/area trend,
  // and the two-value temp+humidity sensor gets an overlaid dual-line chart.
  Widget _buildChartSection(BuildContext context) {
    if (_isDual) {
      return FutureBuilder<(List<TimeSeriesPoint>, List<TimeSeriesPoint>)>(
        future: _dualFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return _loadingBox();
          if (snap.hasError || snap.data == null) return _errorBox();
          final (temp, humidity) = snap.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DualTrendChart(temperature: temp, humidity: humidity),
              const SizedBox(height: 16),
              TimeSeriesAnalysisCard(points: temp, unit: '°C'),
              const SizedBox(height: 14),
              TimeSeriesAnalysisCard(points: humidity, unit: '%'),
            ],
          );
        },
      );
    }

    return FutureBuilder<List<TimeSeriesPoint>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return _loadingBox();
        if (snap.hasError) return _errorBox();
        final points = snap.data ?? [];
        if (_isEvent) {
          final eventLabel = widget.kind == SensorKind.flame ? 'Flame' : 'Motion';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EventBarChart(
                points: points,
                eventLabel: eventLabel,
                color: widget.kind == SensorKind.flame ? AppColors.danger : AppColors.warning,
              ),
              const SizedBox(height: 16),
              TimeSeriesAnalysisCard(points: points, isEvent: true, eventLabel: eventLabel),
            ],
          );
        }
        final unitSuffix = widget.kind.unit.isEmpty ? '' : ' ${widget.kind.unit}';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrendChart(points: points, unit: widget.kind.unit),
            const SizedBox(height: 16),
            TimeSeriesAnalysisCard(points: points, unit: unitSuffix),
          ],
        );
      },
    );
  }

  String _description(SensorKind kind) {
    switch (kind) {
      case SensorKind.flame:
        return 'The flame sensor watches for infrared signatures from open flame. A detection immediately triggers the full-screen alert and, in Auto mode, an automatic maximum-speed reverse escape.';
      case SensorKind.gas:
        return 'The MQ-135 reports a raw 10-bit analog reading (0-1023) from Arduino pin A0 — higher counts mean more combustible/smoke gas. The danger threshold is a placeholder until you test the sensor and share real readings.';
      case SensorKind.pir:
        return 'The passive infrared sensor flags nearby motion. A detection shows as a notification rather than the full alarm — only flame and gas raise the critical alert. Flip on the radar sweep above for a live ultrasonic scan of the area using the same servo.';
      case SensorKind.humidityTemp:
        return 'Combined humidity and temperature readings (DHT11, 0-50°C / 20-90%RH range) surface as notifications when they run high — they don\'t trigger the critical alarm.';
    }
  }
}

/// Half-gauge summary strip for the report page — shown above the trend
/// chart per the brief. Event sensors show one gauge (current alert
/// state); the compound humidity/temp sensor shows two, side by side.
class _SummaryGauges extends StatelessWidget {
  final SensorKind kind;
  const _SummaryGauges({required this.kind});

  @override
  Widget build(BuildContext context) {
    return Consumer<CarState>(
      builder: (context, car, _) {
        final s = car.sensors;
        switch (kind) {
          case SensorKind.flame:
            return _gaugeCard(
              label: 'Live reading',
              value: s.flameDetected ? 1 : 0.05,
              bigValue: s.flameDetected ? 'FIRE' : 'Clear',
              color: s.flameDetected ? AppColors.danger : AppColors.success,
            );
          case SensorKind.pir:
            return _gaugeCard(
              label: 'Live reading',
              value: s.pirMotion ? 1 : 0.05,
              bigValue: s.pirMotion ? 'Motion' : 'Still',
              color: s.pirMotion ? AppColors.warning : AppColors.success,
            );
          case SensorKind.gas:
            return _gaugeCard(
              label: 'Live reading',
              value: (s.gasRaw / SensorThresholds.gasMaxRaw).clamp(0, 1).toDouble(),
              bigValue: '${s.gasRaw.toStringAsFixed(0)} raw',
              color: s.gasRaw >= SensorThresholds.gasDangerRaw ? AppColors.danger : AppColors.success,
            );
          case SensorKind.humidityTemp:
            return Row(
              children: [
                Expanded(
                  child: _gaugeCard(
                    label: 'Temperature',
                    value: (s.temperature / SensorThresholds.tempMaxC).clamp(0, 1).toDouble(),
                    bigValue: '${s.temperature.toStringAsFixed(1)}°C',
                    color: s.temperature >= SensorThresholds.tempNotifyC ? AppColors.warning : AppColors.success,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _gaugeCard(
                    label: 'Humidity',
                    value: (s.humidity / 100).clamp(0, 1).toDouble(),
                    bigValue: '${s.humidity.toStringAsFixed(0)}%',
                    color: AppColors.blue400,
                  ),
                ),
              ],
            );
        }
      },
    );
  }

  Widget _gaugeCard({required String label, required double value, required String bigValue, required Color color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.blue50,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 4),
          AspectRatio(
            aspectRatio: 2,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: value, end: value),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, animatedValue, child) {
                return CustomPaint(
                  painter: HalfGaugePainter(
                    value: animatedValue,
                    trackColor: AppColors.blue100,
                    valueGradient: AppColors.gaugeGradient,
                  ),
                  child: child,
                );
              },
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: FittedBox(
                    child: Text(
                      bigValue,
                      style: const TextStyle(color: AppColors.textOnLight, fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
