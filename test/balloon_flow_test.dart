import 'package:dotline_duel/game/controllers/game_controller.dart';
import 'package:dotline_duel/game/controllers/player_agent.dart';
import 'package:dotline_duel/game/models/balloon.dart';
import 'package:dotline_duel/game/models/game_config.dart';
import 'package:dotline_duel/game/models/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/scripted_agent.dart';
import 'support/sim.dart';

const emptyBoard = GameConfig(obstacleSeed: 1, obstacleDensity: 0);

/// Bot balloon centres (top row).
const left = Offset(250, 82);
const middle = Offset(500, 82);
const right = Offset(750, 82);

GameController human(
  List<Offset> waypoints, {
  GameConfig config = emptyBoard,
}) => skipToPlaying(
  GameController(
    config: config,
    bottomAgent: ScriptedAgent(waypoints: waypoints),
    topAgent: IdleAgent(),
  ),
);

void main() {
  test('touching an opponent balloon after crossing pops it', () {
    final c = human(const [Offset(750, 150), right]);
    runUntil(c, () => c.top.balloons[2].status != BalloonStatus.intact);
    expect(c.top.balloons[2].status, BalloonStatus.popping);
    expect(c.phase.value, GamePhase.playing, reason: 'play never pauses');
    expect(c.bottom.stats.balloonsDestroyed, 1);
    expect(c.bottom.stats.bankedScore, greaterThan(0), reason: 'run banked');
    expect(c.bottom.runStatus, RunStatus.finished);

    runFor(c, emptyBoard.balloonAnimationDuration.inMilliseconds / 1000 + 0.05);
    expect(c.top.balloons[2].status, BalloonStatus.destroyed);
    expect(c.top.balloonsStanding, 2);
  });

  test('after a pop the pen respawns at its start on the same field', () {
    final c = human(const [Offset(500, 150), middle]);
    final field = c.field.value;
    runUntil(c, () => c.bottom.stats.balloonsDestroyed == 1);
    final poppedAt = c.time;
    runUntil(c, () => c.bottom.runStatus != RunStatus.finished);
    expect(
      c.time - poppedAt,
      closeTo(emptyBoard.respawnDelay.inMilliseconds / 1000, 0.05),
    );
    expect(c.bottom.runStatus, RunStatus.ready);
    expect(c.bottom.position, emptyBoard.bottomStart);
    expect(c.bottom.hasCrossed, isFalse);
    expect(identical(c.field.value, field), isTrue, reason: 'no new layout');
  });

  test('one balloon per run: the pen cannot chain pops', () {
    // Sweeps across all three balloons in a single run.
    final c = human(const [Offset(250, 150), left, middle, right]);
    runFor(c, 4);
    expect(c.bottom.stats.balloonsDestroyed, 1);
    expect(c.top.balloons.where((b) => b.isAlive).length, 2);
  });

  test("touching your own balloons does nothing", () {
    final c = human(const [Offset(500, 1518)]);
    runFor(c, 2);
    expect(c.bottom.balloonsStanding, 3);
    expect(c.bottom.stats.balloonsDestroyed, 0);
  });

  test('popping all three balloons over three runs wins immediately', () {
    final agent = ScriptedAgent(waypoints: const [Offset(250, 150), left]);
    final c = skipToPlaying(
      GameController(
        config: emptyBoard,
        bottomAgent: agent,
        topAgent: IdleAgent(),
      ),
    );
    for (final target in const [left, middle, right]) {
      agent.waypoints = [Offset(target.dx, 150), target];
      runUntil(
        c,
        () =>
            c.bottom.runStatus == RunStatus.running ||
            c.phase.value == GamePhase.gameOver,
      );
      runUntil(c, () => c.bottom.runStatus != RunStatus.running);
    }
    expect(c.phase.value, GamePhase.gameOver);
    expect(c.endTrigger, GameEndTrigger.balloons);
    expect(c.bottom.stats.balloonsDestroyed, 3);
    expect(c.result.value!.outcome.winner, 0);
    expect(c.result.value!.outcome.reason, WinReason.allBalloonsDestroyed);
    // The last pop still finishes animating after the whistle.
    runFor(c, 1);
    expect(c.top.balloonsStanding, 0);
  });
}
