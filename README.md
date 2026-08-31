# Inspection Rover — Flutter Control App

A two-page Flutter app for controlling and monitoring an Arduino/ESP32
inspection car equipped with five sensors (ultrasonic, flame, gas, PIR,
humidity & temperature).

## Run it locally

This repo ships only `lib/` + `pubspec.yaml` (no `android/`/`ios/`
folders yet). Generate them once, then run as normal:

```bash
flutter create --platforms=android --org com.inspectionrover .
flutter pub get
flutter run
```

Requires Flutter 3.22+ (Dart 3.3+). No hardware is required to try the
app — it runs against `MockCarConnectionService`, which simulates live
sensor data and command acknowledgements.

## Host on GitHub and get a built APK (no local Flutter needed)

A workflow at `.github/workflows/build-apk.yml` builds a release APK
for you in GitHub's cloud on every push:

1. Create a new GitHub repo and push this project to it:
   ```bash
   cd inspection_car_app
   git init
   git add .
   git commit -m "Initial commit"
   git branch -M main
   git remote add origin https://github.com/<your-username>/<your-repo>.git
   git push -u origin main
   ```
2. On GitHub, open the **Actions** tab — the "Build APK" workflow runs
   automatically. When it finishes (a few minutes), open the run and
   download the **inspection-rover-apk** artifact — that's your `.apk`.
3. To also get it attached to a proper **Release** (a persistent
   download link, not just a build artifact), tag a version and push
   the tag:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
   The workflow will attach `app-release.apk` to the Release it creates
   for that tag automatically.
4. Install the APK: download it to your Android phone (or `adb install
   app-release.apk`), then enable "install from unknown sources" if
   prompted, since it isn't signed for the Play Store.

This is a debug/unsigned release build meant for testing. For a Play
Store submission you'll need to set up your own signing key and update
`android/app/build.gradle` accordingly.

## New in this update (real ESP32 connection + smarter alerts)

- **Real WebSocket connection** — `services/websocket_car_connection_service.dart`
  connects to the ESP32 over a single WebSocket (`ws://<host>:81/ws` by
  default) using JSON messages. Full wire protocol is documented at the
  top of that file — the ESP32 firmware needs to speak it. Auto-reconnects
  with backoff if the link drops. A **Connection panel** at the top of
  the Control page shows live status (Demo / Connecting / Connected /
  Reconnecting / Error) and lets you enter the rover's IP or drop back
  to demo mode (`widgets/connection_panel.dart`).
- **Alarm system, scoped to flame + gas only** — the full-screen overlay
  and voice alarm (`services/voice_alert_service.dart`, via `flutter_tts`,
  works offline) now trigger *only* for flame or dangerous gas
  (`CarState.criticalAlertActive`). PIR motion, high temperature, and
  high humidity instead show as a plain snackbar notification
  (`CarState.notifications`, listened to in `home_shell.dart`) —
  never a takeover screen. The ultrasonic obstacle routine still shows a
  small header chip, same as before, but never the full alarm.
- **Global alarm mute** — a bell icon in the status header
  (`StatusHeader`/`_AlertMuteButton`) turns the whole alarm system off
  (voice + overlay), silencing anything currently sounding, until tapped
  again. Sensor readings and notifications keep working either way.
- **Gauge ranges now match real sensor ranges** — `SensorThresholds` in
  `models/sensor_data.dart` documents each range and threshold:
  - Gas (MQ-135, Arduino A0): raw 10-bit ADC, 0–1023. The gauge fills
    across that exact range; the *danger threshold* (650) is a
    placeholder — the model's doc comment explains why and where to
    change it once you've tested the sensor.
  - Temperature (DHT11): 0–50°C gauge range, 38°C "high" placeholder.
  - Humidity (DHT11): 0–100% gauge range, 75% "high" placeholder.
  All three placeholders live in one place (`SensorThresholds`) so
  updating them after you test each sensor doesn't require touching any
  UI code.

## Earlier update

- **Speed control (Manual + Auto)**
  - Manual mode now shows a vertical throttle slider next to the D-pad
    (`widgets/throttle_slider.dart`). Drag it to set 15–100% speed;
    every D-pad press uses that value. If you drag the throttle *while*
    holding a direction, the new speed is sent immediately
    (`CarState.setManualSpeed`).
  - Auto mode shows a "Max auto speed" cap slider
    (`widgets/auto_speed_cap_card.dart`). This is a ceiling, not a
    direct throttle — `CarState._startAutoLoop` reads it on every drive
    tick, so the car never drives itself faster than the chosen cap,
    even on a long clear stretch. The ultrasonic reverse/scan sequence
    also uses this cap for its reverse speed while in Auto mode.
  - The flame-escape reverse is a safety override and is **not** capped
    — it always reverses at absolute maximum speed regardless of either
    slider.
- **Chart label decluttering** — all four history charts (gas/flame/PIR
  trend & bar charts, temp+humidity dual chart, battery chart) now
  share `widgets/chart_axis_labels.dart`, which renders exactly 3
  x-axis timestamps (start / middle / end) instead of one per
  interval-selected bar, so labels never overlap regardless of point
  count or screen width.
- **Radar sweep preview** — the PIR report page
  (`pages/sensor_detail_page.dart`) now embeds a live radar-style card
  (`widgets/radar_sweep_card.dart`) showing the HC-SR04 servo sweep
  (GPIO18 servo / GPIO17 Trig / GPIO16 Echo). It has its own on/off
  toggle so the servo isn't left sweeping indefinitely, and
  auto-stops if you navigate away from the page while it's on. The mock
  connection service (`services/car_connection_service.dart`) simulates
  the sweep via `radarStream`/`startRadarSweep`/`stopRadarSweep` — a
  real implementation should drive the physical servo the same way and
  stream back `{angle, distanceCm}` per step.

## Structure

```
lib/
  main.dart                     App entry point, theme + Provider wiring
  theme/app_theme.dart          Light color tokens (brand blue ramp + turquoise/pink accents) and ThemeData
  models/sensor_data.dart       DriveMode, DriveCommand, SensorSnapshot, BatteryStatus, CarStatus, AlertEvent, etc.
  services/car_connection_service.dart  Transport abstraction + mock implementation
                                 (sensors, connection, battery, and radar sweep streams + history fetchers)
  state/car_state.dart          ChangeNotifier: mode switching, obstacle-avoidance
                                 state machine, flame-escape logic, alert lifecycle, battery state,
                                 manual/auto speed control, radar sweep control
  pages/
    home_shell.dart             Bottom navigation between Control and Dashboard
    control_page.dart           Page 1 — status header, mode toggle, D-pad + throttle (manual) or
                                 auto-speed cap (auto), Battery button, Stop Alert
    dashboard_page.dart         Page 2 — responsive 2x2 grid, always fills the screen with no overflow
    sensor_detail_page.dart     Historical report per sensor — half gauge(s), radar card (PIR only),
                                 and a chart suited to the sensor
    battery_report_page.dart    Animated battery visual, voltage/runtime stats, battery history chart
  widgets/
    status_header.dart
    mode_toggle.dart
    directional_pad.dart
    circular_control_button.dart
    throttle_slider.dart        Manual-mode vertical throttle
    auto_speed_cap_card.dart    Auto-mode max-speed ceiling slider
    radar_sweep_card.dart       Embedded live radar preview for the PIR report page
    half_gauge_painter.dart
    half_gauge_card.dart        Gauge card for continuous sensors (gas, temp/humidity)
    status_pulse_card.dart      Pulsing status card for binary/event sensors (flame, PIR)
    battery_visual.dart         Large animated liquid-fill battery indicator
    chart_axis_labels.dart      Shared start/mid/end x-axis label builder (declutter fix)
    trend_chart.dart            Line/area chart (gas)
    dual_trend_chart.dart       Overlaid two-series line chart (temperature + humidity)
    event_bar_chart.dart        Bar/event chart (flame, PIR history)
    alert_overlay.dart
```

## Behavior implemented

- **Manual mode** — press-and-hold circular buttons (forward/back/left/right)
  at the speed set by the throttle slider. The car moves only while a
  button is held and stops the instant it's released or the pointer
  leaves the button; no separate stop button.
- **Ultrasonic routine (both modes, always on)** — on obstacle detection:
  stop → reverse two steps (at the current mode's speed) → servo scan
  right → proceed if clear, else scan left → proceed if clear, else stay
  stopped and keep the alert up.
- **Auto mode** — drives forward continuously, capped at the operator's
  chosen max-auto-speed, running the same ultrasonic routine automatically.
- **Flame escape** — in Auto mode, a flame reading immediately reverses
  the car at absolute maximum speed (uncapped) for a few seconds before
  resuming patrol; in both modes it raises the full-screen alert right away.
- **Alerts** — full-screen red overlay + haptic feedback (`HapticFeedback.heavyImpact`),
  persists until the operator taps **Stop Alert** on the overlay or the
  control page.
- **Dashboard** — a 2x2 grid that always exactly fills the screen (no
  overflow/overlap on any device size). Continuous sensors (gas,
  temperature/humidity) get a half-circle gauge card; binary/event
  sensors (flame, PIR) get a pulsing status card instead. Tapping a card
  opens a detail page with matching half-gauge(s), a live radar preview
  (PIR only), and a chart chosen for that sensor type.
- **Battery** — the control page's battery button opens a report with a
  large animated liquid-fill battery visual, pack voltage, estimated
  runtime, and a battery level history chart.

## Wiring up real hardware

Everything the UI needs from the rover goes through the
`CarConnectionService` interface in `lib/services/car_connection_service.dart`.
Swap `MockCarConnectionService` for a real implementation and nothing
else in the app needs to change:

- `sendCommand(DriveCommand, speedPercent)` → e.g. `POST /command` or a
  WebSocket message `{"cmd":"forward","speed":55}` — `speedPercent` now
  comes from the throttle slider (manual) or the auto-speed cap (auto).
- `sensorStream` → feed it from a WebSocket (`web_socket_channel` is
  already a dependency) or a REST polling loop hitting `GET /sensors`
- `fetchHistory(SensorKind)` → `GET /history/:kind`
- `radarStream` / `startRadarSweep()` / `stopRadarSweep()` → drive the
  servo (GPIO18) across 0–180° while pinging the HC-SR04
  (Trig GPIO17 / Echo GPIO16, per the wiring plan) at each step, and
  stream `RadarSweepReading(angleDegrees, distanceCm)` back per step.

A couple of hardware notes carried over from earlier discussion, worth
keeping in mind when you wire the ESP32 side:
- Keep motors on a separate power rail from the ESP32/sensor 5V rail
  (via a motor driver like an L298N/TB6612) to avoid brownouts.
- ESP32 GPIOs are 3.3V logic — level-shift any 5V sensor outputs.

## Notes

- State management uses `provider` (`ChangeNotifier` + `Consumer`).
- Charts use `fl_chart`; gauges and the radar sweep are custom
  `CustomPainter`s, so no extra gauge/radar package is required.
- This environment couldn't run `flutter pub get` / `flutter analyze`
  (no Flutter SDK or pub.dev access), so the code has been reviewed by
  hand and brace/import-checked, but please run `flutter analyze` once
  you pull it into a Flutter environment before shipping.
