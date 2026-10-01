import 'package:dotline_duel/game/controllers/game_controller.dart';
import 'package:dotline_duel/game/controllers/player_agent.dart';
import 'package:dotline_duel/game/models/balloon.dart';
import 'package:dotline_duel/game/models/game_config.dart';
import 'package:dotline_duel/game/models/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/scripted_agent.dart';

const emptyBoard = GameConfig(obstacleSeed: 1, obstacleDensity: 0);

void runUntil(
  GameController c,
  bool Function() done, {
  double maxSeconds = 30,
}) {
  for (var t = 0.0; t < maxSeconds && !done(); t += 1 / 60) {
    c.tick(1 / 60);
  }
}

/// A human agent that does not pick a balloon on its own.
class _HesitantAgent extends ScriptedAgent {
  _HesitantAgent() : super(waypoints: const [Offset(500, 150)]);

  @override
  int? chooseBalloon(List<int> available, double elapsed) => null;
}

void main() {
  test('crossing leads to targeting; the chosen balloon pops', () {
    final human = ScriptedAgent(waypoints: const [Offset(500, 150)])
      ..balloonChoice = 2;
    final c = GameController(
      config: emptyBoard,
      bottomAgent: human,
      topAgent: IdleAgent(),
    );

    runUntil(c, () => c.phase.value == GamePhase.targeting);
    expect(c.roundWinner, c.bottom);
    expect(c.defender, c.top);

    runUntil(c, () => c.phase.value == GamePhase.balloonDestroyed);
    expect(c.top.balloons[2].status, BalloonStatus.popping);

    runUntil(c, () => c.phase.value == GamePhase.playing);
    expect(c.top.balloons[2].status, BalloonStatus.destroyed);
    expect(c.top.balloonsStanding, 2);
    expect(c.bottom.stats.balloonsDestroyed, 1);
    expect(c.round.value, 2);
    expect(c.bottom.position, emptyBoard.bottomStart, reason: 'players reset');
  });

  test('a destroyed balloon cannot be targeted again', () {
    final human = ScriptedAgent(waypoints: const [Offset(500, 150)])
      ..balloonChoice = 0;
    final c = GameController(
      config: emptyBoard,
      bottomAgent: human,
      topAgent: IdleAgent(),
    );
    runUntil(c, () => c.round.value == 2 && c.phase.value == GamePhase.playing);
    expect(c.top.aliveBalloonIndexes, [1, 2]);
    // Asking for balloon 0 again is ignored; the agent falls back.
    runUntil(c, () => c.round.value == 3 && c.phase.value == GamePhase.playing);
    expect(c.top.balloons[0].status, BalloonStatus.destroyed);
    expect(c.top.balloonsStanding, 1);
  });

  test('an undecided attacker gets a balloon picked when time runs out', () {
    final c = GameController(
      config: emptyBoard,
      bottomAgent: _HesitantAgent(),
      topAgent: IdleAgent(),
    );
    runUntil(c, () => c.phase.value == GamePhase.targeting);
    final secs = emptyBoard.targetingDuration.inMilliseconds / 1000;
    runUntil(
      c,
      () => c.phase.value == GamePhase.balloonDestroyed,
      maxSeconds: secs + 1,
    );
    expect(c.phase.value, GamePhase.balloonDestroyed);
  });

  test('destroying all three balloons wins immediately', () {
    final human = ScriptedAgent(waypoints: const [Offset(500, 150)]);
    final c = GameController(
      config: emptyBoard,
      bottomAgent: human,
      topAgent: IdleAgent(),
    );
    runUntil(c, () => c.phase.value == GamePhase.gameOver, maxSeconds: 60);
    expect(c.phase.value, GamePhase.gameOver);
    expect(c.endTrigger, GameEndTrigger.balloons);
    expect(c.top.balloonsStanding, 0);
    expect(c.bottom.stats.balloonsDestroyed, 3);
    expect(c.round.value, 3, reason: 'no further round is started');
  });
}
