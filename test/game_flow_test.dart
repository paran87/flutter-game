import 'package:dotline_duel/game/controllers/game_controller.dart';
import 'package:dotline_duel/game/controllers/player_agent.dart';
import 'package:dotline_duel/game/models/game_config.dart';
import 'package:dotline_duel/game/models/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/scripted_agent.dart';
import 'support/sim.dart';

/// No dots, fixed seed: movement rules only.
const emptyBoard = GameConfig(obstacleSeed: 1, obstacleDensity: 0);

void main() {
  group('failures and attempts', () {
    test('running out of ink fails the run and costs one attempt', () {
      final config = emptyBoard.copyWith(inkCapacity: 300);
      // Wander sideways so the pen never reaches the goal.
      final human = ScriptedAgent(
        waypoints: const [
          Offset(200, 1390),
          Offset(800, 1390),
          Offset(200, 1390),
        ],
      );
      final c = skipToPlaying(
        GameController(
          config: config,
          bottomAgent: human,
          topAgent: IdleAgent(),
        ),
      );
      runFor(c, 1.5);
      final p = c.bottom;
      expect(p.attemptsRemaining, 2);
      expect(p.stats.failedRuns, 1);
      expect(p.stats.totalDistance, greaterThan(0), reason: 'distance is kept');
      expect(p.stats.bankedScore, 0, reason: 'failed run score is forfeited');
      expect(c.lastFailure.value?.reason, FailureReason.outOfInk);
      expect(c.phase.value, GamePhase.playing, reason: 'the game is not reset');
    });

    test('player is reset to start after the failure animation', () {
      final config = emptyBoard.copyWith(inkCapacity: 200);
      final human = ScriptedAgent(
        waypoints: const [Offset(100, 1395), Offset(900, 1395)],
      );
      final c = skipToPlaying(
        GameController(
          config: config,
          bottomAgent: human,
          topAgent: IdleAgent(),
        ),
      );
      runFor(c, 0.8);
      expect(c.bottom.runStatus, RunStatus.failed);
      human.waypoints = [];
      runFor(c, config.failureResetDuration.inMilliseconds / 1000 + 0.1);
      expect(c.bottom.runStatus, RunStatus.ready);
      expect(c.bottom.position, config.bottomStart);
      expect(
        c.bottom.trace.points.length,
        1,
        reason: 'only the run trace is cleared',
      );
    });

    test('lifting the pen briefly is forgiven; too long fails the run', () {
      final human = ScriptedAgent(waypoints: const [Offset(500, 900)]);
      final c = skipToPlaying(
        GameController(
          config: emptyBoard,
          bottomAgent: human,
          topAgent: IdleAgent(),
        ),
      );
      runFor(c, 0.3);
      expect(c.bottom.runStatus, RunStatus.running);
      human.penDown = false;
      runFor(c, 1.0); // < 1.5 s grace
      expect(c.bottom.runStatus, RunStatus.running);
      human.penDown = true;
      runFor(c, 0.1);
      human.penDown = false;
      runFor(c, 1.6);
      expect(c.bottom.runStatus, isNot(RunStatus.running));
      expect(c.lastFailure.value?.reason, FailureReason.penLifted);
      expect(c.bottom.attemptsRemaining, 2);
    });

    test('obstacle collisions never consume attempts', () {
      const dense = GameConfig(obstacleSeed: 5, obstacleDensity: 1.4);
      final human = ScriptedAgent(
        waypoints: [Offset(500, dense.fieldRect.center.dy)],
      );
      final c = skipToPlaying(
        GameController(
          config: dense,
          bottomAgent: human,
          topAgent: IdleAgent(),
        ),
      );
      runFor(c, 2);
      expect(c.bottom.stats.totalCollisions, greaterThan(0));
      expect(c.bottom.attemptsRemaining, dense.attemptsPerPlayer);
    });

    test('zero attempts eliminates a player; both out ends the game', () {
      final config = emptyBoard.copyWith(inkCapacity: 120);
      List<Offset> wander() => const [Offset(150, 1395), Offset(850, 1395)];
      final a = ScriptedAgent(waypoints: wander());
      final b = ScriptedAgent(
        waypoints: const [Offset(150, 205), Offset(850, 205)],
      );
      final c = skipToPlaying(
        GameController(config: config, bottomAgent: a, topAgent: b),
      );
      runFor(c, 8);
      expect(c.bottom.attemptsRemaining, 0);
      expect(c.top.attemptsRemaining, 0);
      expect(c.bottom.runStatus, RunStatus.eliminated);
      expect(c.phase.value, GamePhase.gameOver);
    });
  });

  group('successful crossing', () {
    test('reaching the far side banks the run and halts the opponent', () {
      final human = ScriptedAgent(waypoints: const [Offset(500, 150)]);
      final bot = ScriptedAgent(
        waypoints: const [Offset(500, 700)],
        maxSpeed: 100,
      );
      final c = skipToPlaying(
        GameController(config: emptyBoard, bottomAgent: human, topAgent: bot),
      );
      runFor(c, 3);
      expect(c.phase.value, isNot(GamePhase.playing));
      final success = c.lastSuccess.value!;
      expect(success.player, c.bottom);
      expect(success.summary.penalties, 0);
      expect(success.summary.runScore, success.summary.distancePoints);
      expect(c.bottom.stats.bankedScore, success.summary.runScore);
      expect(c.bottom.stats.successfulRuns, 1);
      expect(c.top.attemptsRemaining, emptyBoard.attemptsPerPlayer);
    });

    test('distance is the travelled path, not vertical progress', () {
      // A zig-zag route is longer than the straight line it covers.
      final human = ScriptedAgent(
        waypoints: const [
          Offset(200, 1100),
          Offset(800, 800),
          Offset(200, 500),
          Offset(500, 150),
        ],
      );
      final c = skipToPlaying(
        GameController(
          config: emptyBoard,
          bottomAgent: human,
          topAgent: IdleAgent(),
        ),
      );
      runFor(c, 6);
      final straight =
          (emptyBoard.bottomStart.dy - emptyBoard.bottomGoalY) *
          emptyBoard.distanceUnitsPerWorldUnit;
      expect(
        c.lastSuccess.value!.summary.distancePoints,
        greaterThan(straight * 1.5),
      );
    });
  });
}
