import 'audio_service.dart';
import 'haptics_service.dart';

/// The game's single outlet for audio + haptic feedback. Game logic says
/// *what happened*; this decides how it feels.
class GameFeedback {
  GameFeedback({AudioService? audio, HapticsService? haptics})
    : audio = audio ?? SystemAudioService(),
      haptics = haptics ?? HapticsService();

  /// Feedback that does nothing (tests, headless simulation).
  GameFeedback.silent()
    : audio = SilentAudioService(),
      haptics = HapticsService(enabled: false);

  final AudioService audio;
  final HapticsService haptics;

  /// [local] is true when the event concerns the player holding the phone.
  void obstacleTouched({required bool local}) {
    audio.play(GameSound.collision);
    if (local) haptics.light();
  }

  void runSucceeded({required bool local}) {
    audio.play(GameSound.success);
    if (local) haptics.medium();
  }

  void runFailed({required bool local}) {
    audio.play(GameSound.failure);
    if (local) haptics.medium();
  }

  void balloonDestroyed({required bool localOwner}) {
    audio.play(GameSound.balloonPop);
    // Losing your own balloon should be felt more than popping theirs.
    localOwner ? haptics.heavy() : haptics.medium();
  }

  void countdownTick() => audio.play(GameSound.countdown);

  void timerWarning() {
    audio.play(GameSound.timerWarning);
    haptics.selection();
  }

  void gameOver({required bool localWon}) {
    audio.play(localWon ? GameSound.victory : GameSound.defeat);
    haptics.heavy();
  }

  void dispose() => audio.dispose();
}
