import 'package:flutter/services.dart';

/// Every sound the game can make. Assets are not bundled yet; implementations
/// map these to files (or synthesis) later without touching game logic.
enum GameSound {
  button,
  move,
  collision,
  balloonPop,
  success,
  failure,
  countdown,
  timerWarning,
  victory,
  defeat,
}

/// Plays game sounds. Swap the implementation to add real audio.
abstract class AudioService {
  bool enabled = true;

  void play(GameSound sound);

  /// Continuous scratch of the pen while drawing (0 = silent).
  void setPenActivity(double intensity) {}

  void dispose() {}
}

/// Default implementation: no bundled assets yet, so only the platform's own
/// UI click is used for buttons. Everything else is a deliberate no-op.
class SystemAudioService extends AudioService {
  @override
  void play(GameSound sound) {
    if (!enabled) return;
    if (sound == GameSound.button) {
      SystemSound.play(SystemSoundType.click);
    }
  }
}

/// Silent implementation for tests.
class SilentAudioService extends AudioService {
  @override
  void play(GameSound sound) {}
}
