import 'package:flutter_tts/flutter_tts.dart';

/// Speaks the flame/gas alarm out loud instead of (or alongside) a
/// vibration. Runs entirely on-device via the platform's TTS engine —
/// no network required.
///
/// Hardened against a few silent-failure modes that don't throw a Dart
/// exception but also don't produce any sound:
///   - Forcing setLanguage('en-US') fails silently on some devices that
///     don't have that exact locale installed, which can leave the
///     engine unable to speak at all. We try it, but don't let a
///     failure there stop us from still attempting speak().
///   - Calling stop() immediately before speak() on some Android TTS
///     engines can race with engine init on the very first call. We
///     only call stop() if something is already speaking.
class VoiceAlertService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool _speaking = false;

  Future<void> _ensureReady() async {
    if (_ready) return;
    try {
      await _tts.setLanguage('en-US');
    } catch (_) {
      // Fall through and use whatever the device's default TTS language is.
    }
    try {
      await _tts.setSpeechRate(0.48);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
    } catch (_) {
      // Non-fatal — worst case the alarm speaks at default rate/pitch.
    }
    await _tts.awaitSpeakCompletion(false);
    _tts.setStartHandler(() => _speaking = true);
    _tts.setCompletionHandler(() => _speaking = false);
    _tts.setCancelHandler(() => _speaking = false);
    _tts.setErrorHandler((_) => _speaking = false);
    _ready = true;
  }

  Future<void> speak(String text) async {
    await _ensureReady();
    if (_speaking) {
      await _tts.stop();
    }
    await _tts.speak(text);
  }

  Future<void> stop() async {
    if (!_ready) return;
    await _tts.stop();
    _speaking = false;
  }
}
