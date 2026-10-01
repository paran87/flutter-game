import '../models/game_result.dart';
import '../models/game_state.dart';

/// Decides the winner. Pure function of the two final lines.
///
/// * Balloon elimination: whoever destroyed all of the opponent's balloons.
/// * Otherwise (timer / nobody can run any more), in order:
///     1. more balloons destroyed
///     2. higher total score
///     3. longer total distance
///     4. draw
///
/// Values are compared as displayed (whole numbers), so the result always
/// matches what the players can see on the result screen.
GameOutcome resolveWinner({
  required ResultLine bottom,
  required ResultLine top,
  required GameEndTrigger trigger,
}) {
  if (trigger == GameEndTrigger.balloons) {
    if (top.balloonsStanding == 0 && bottom.balloonsStanding > 0) {
      return const GameOutcome(0, WinReason.allBalloonsDestroyed);
    }
    if (bottom.balloonsStanding == 0 && top.balloonsStanding > 0) {
      return const GameOutcome(1, WinReason.allBalloonsDestroyed);
    }
  }

  int? better(int a, int b) => a == b ? null : (a > b ? 0 : 1);

  final byBalloons = better(bottom.balloonsDestroyed, top.balloonsDestroyed);
  if (byBalloons != null) {
    return GameOutcome(byBalloons, WinReason.moreBalloonsDestroyed);
  }
  final byScore = better(bottom.score, top.score);
  if (byScore != null) return GameOutcome(byScore, WinReason.higherScore);
  final byDistance = better(bottom.distance, top.distance);
  if (byDistance != null) {
    return GameOutcome(byDistance, WinReason.longerDistance);
  }
  return const GameOutcome(null, WinReason.draw);
}
