import 'package:dotline_duel/game/controllers/game_controller.dart';
import 'package:dotline_duel/game/controllers/player_agent.dart';
import 'package:dotline_duel/game/controllers/timer_controller.dart';
import 'package:dotline_duel/game/models/game_config.dart';
import 'package:dotline_duel/game/models/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/scripted_agent.dart';
import 'support/sim.dart';

void main() {
  group('TimerController', () {
    TimerController make() => TimerController(
      duration: const Duration(seconds: 120),
      warningSeconds: 30,
      criticalSeconds: 10,
    );

    test('counts down and reports levels', () {
      final t = make();
      expect(t.displaySeconds, 120);
      expect(t.level, TimerLevel.normal);
      t.tick(89.5);
      expect(t.displaySeconds, 31);
      expect(t.tick(1), TimerLevel.warning);
      t.tick(19.6);
      expect(t.level, TimerLevel.critical);
      expect(t.tick(100), TimerLevel.expired);
      expect(t.displaySeconds, 0);
      expect(t.isExpired, isTrue);
    });

    test('never goes negative and stops after expiring', () {
      final t = make()..tick(500);
      expect(t.remaining, 0);
      expect(t.tick(1), isNull);
    });
  });

  group('match clock in the game', () {
    const quick = GameConfig(
      obstacleSeed: 3,
      obstacleDensity: 0,
      gameDuration: Duration(seconds: 3),
    );

    test('the clock does not run during intro and countdown', () {
      final c = GameController(
        config: quick,
        bottomAgent: IdleAgent(),
        topAgent: IdleAgent(),
      );
      runFor(c, 2.0);
      expect(c.phase.value, isNot(GamePhase.playing));
      expect(c.timer.remaining, 3);
    });

    test('timer reaching zero during movement ends the game immediately', () {
      // Slow pen that cannot cross in 3 seconds.
      final human = ScriptedAgent(
        waypoints: const [Offset(500, 150)],
        maxSpeed: 120,
      );
      final c = skipToPlaying(
        GameController(
          config: quick,
          bottomAgent: human,
          topAgent: IdleAgent(),
        ),
      );
      runFor(c, 3.05);
      expect(c.phase.value, GamePhase.gameOver);
      expect(c.endTrigger, GameEndTrigger.timer);
      expect(c.timerSeconds.value, 0);

      // Input is ignored afterwards: the pen and the clock are frozen.
      final frozen = c.bottom.position;
      runFor(c, 1);
      expect(c.bottom.position, frozen);
      expect(c.timer.remaining, 0);

      // The interrupted run's distance still counts.
      expect(c.result.value!.bottom.distance, greaterThan(0));
    });

    test('the clock pauses while a balloon is being attacked', () {
      final human = ScriptedAgent(waypoints: const [Offset(500, 150)]);
      final c = skipToPlaying(
        GameController(
          config: quick.copyWith(gameDuration: const Duration(seconds: 60)),
          bottomAgent: human,
          topAgent: IdleAgent(),
        ),
      );
      runUntil(c, () => c.phase.value == GamePhase.targeting);
      final before = c.timer.remaining;
      runFor(c, 0.3);
      expect(c.timer.remaining, before);
    });

    test('pausing freezes everything', () {
      final human = ScriptedAgent(waypoints: const [Offset(500, 150)]);
      final c = skipToPlaying(
        GameController(
          config: quick,
          bottomAgent: human,
          topAgent: IdleAgent(),
        ),
      );
      c.setPaused(true);
      final pos = c.bottom.position;
      final clock = c.timer.remaining;
      runFor(c, 2);
      expect(c.bottom.position, pos);
      expect(c.timer.remaining, clock);
      c.setPaused(false);
      runFor(c, 0.2);
      expect(c.bottom.position, isNot(pos));
    });
  });
}
