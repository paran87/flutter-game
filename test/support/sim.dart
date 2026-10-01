import 'package:dotline_duel/game/controllers/game_controller.dart';
import 'package:dotline_duel/game/models/game_state.dart';

const frame = 1 / 60;

void runFor(GameController c, double seconds) {
  final steps = (seconds / frame).round();
  for (var i = 0; i < steps; i++) {
    c.tick(frame);
  }
}

void runUntil(
  GameController c,
  bool Function() done, {
  double maxSeconds = 30,
}) {
  for (var t = 0.0; t < maxSeconds && !done(); t += frame) {
    c.tick(frame);
  }
}

/// Skips the intro banner and 3-2-1 countdown.
GameController skipToPlaying(GameController c) {
  runUntil(c, () => c.phase.value == GamePhase.playing, maxSeconds: 10);
  return c;
}
