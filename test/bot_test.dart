import 'package:dotline_duel/game/controllers/bot_controller.dart';
import 'package:dotline_duel/game/controllers/game_controller.dart';
import 'package:dotline_duel/game/controllers/player_agent.dart';
import 'package:dotline_duel/game/models/game_config.dart';
import 'package:dotline_duel/game/models/game_state.dart';
import 'package:dotline_duel/game/utils/distance_utils.dart';
import 'package:dotline_duel/game/utils/path_utils.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/sim.dart';

/// Stats for one bot run (start → through the dots → into a balloon).
({double seconds, int penalties, double inkUsed}) crossOnce(
  BotDifficulty difficulty,
  int seed,
) {
  final config = GameConfig(obstacleSeed: seed, botDifficulty: difficulty);
  final bot = BotController(difficulty: difficulty, seed: seed);
  final c = skipToPlaying(
    GameController(config: config, bottomAgent: IdleAgent(), topAgent: bot),
  );
  final start = c.time;
  runUntil(c, () => c.top.stats.balloonsDestroyed == 1, maxSeconds: 20);
  expect(
    c.top.stats.balloonsDestroyed,
    1,
    reason: '$difficulty bot must pop a balloon (seed $seed)',
  );
  final distanceWorld =
      c.top.stats.totalDistance / config.distanceUnitsPerWorldUnit;
  return (
    seconds: c.time - start,
    penalties: c.top.stats.totalPenalties,
    inkUsed: distanceWorld / config.inkCapacity,
  );
}

void main() {
  test('path utils: chaikin keeps endpoints, resample spacing is even', () {
    const raw = [Offset(0, 0), Offset(100, 0), Offset(100, 100)];
    final smooth = chaikinSmooth(raw);
    expect(smooth.first, raw.first);
    expect(smooth.last, raw.last);
    expect(pathLength(smooth), lessThan(pathLength(raw)));
    final even = resample(raw, 10);
    for (var i = 1; i < even.length - 1; i++) {
      expect((even[i] - even[i - 1]).distance, closeTo(10, 1e-6));
    }
  });

  test('bot travels visibly (no teleporting) and leaves a trace', () {
    const config = GameConfig(obstacleSeed: 4);
    final bot = BotController(difficulty: BotDifficulty.normal, seed: 4);
    final c = skipToPlaying(
      GameController(config: config, bottomAgent: IdleAgent(), topAgent: bot),
    );
    var last = c.top.position;
    var maxStep = 0.0;
    for (var i = 0; i < 120; i++) {
      c.tick(frame);
      final step = (c.top.position - last).distance;
      if (step > maxStep) maxStep = step;
      last = c.top.position;
    }
    expect(maxStep, lessThanOrEqualTo(bot.maxSpeed * frame + 1e-6));
    expect(c.top.trace.points.length, greaterThan(20));
    expect(bot.plannedPath, isNotEmpty);
  });

  test('every difficulty crosses within its ink on many layouts', () {
    for (final d in BotDifficulty.values) {
      for (var seed = 1; seed <= 8; seed++) {
        final r = crossOnce(d, seed);
        expect(
          r.inkUsed,
          lessThan(1.0),
          reason: '$d seed $seed used ${r.inkUsed}',
        );
      }
    }
  });

  test('harder bots are faster and cleaner on average', () {
    Map<String, double> averages(BotDifficulty d) {
      var seconds = 0.0, penalties = 0.0;
      const n = 10;
      for (var seed = 1; seed <= n; seed++) {
        final r = crossOnce(d, seed);
        seconds += r.seconds;
        penalties += r.penalties;
      }
      return {'seconds': seconds / n, 'penalties': penalties / n};
    }

    final easy = averages(BotDifficulty.easy);
    final normal = averages(BotDifficulty.normal);
    final hard = averages(BotDifficulty.hard);
    // ignore: avoid_print
    print('easy $easy\nnormal $normal\nhard $hard');
    expect(easy['seconds']!, greaterThan(normal['seconds']!));
    expect(normal['seconds']!, greaterThan(hard['seconds']!));
    expect(easy['penalties']!, greaterThan(normal['penalties']!));
    expect(normal['penalties']!, greaterThanOrEqualTo(hard['penalties']!));
  });

  test('bot aims each run at a balloon that is still standing', () {
    const config = GameConfig(obstacleSeed: 6);
    final bot = BotController(difficulty: BotDifficulty.hard, seed: 6);
    final c = skipToPlaying(
      GameController(config: config, bottomAgent: IdleAgent(), topAgent: bot),
    );
    final popped = <int>{};
    for (var i = 0; i < 2; i++) {
      final target = bot.targetBalloon!;
      expect(c.bottom.balloons[target].isAlive, isTrue);
      expect(popped, isNot(contains(target)));
      runUntil(c, () => c.top.stats.balloonsDestroyed == i + 1);
      popped.add(target);
      expect(c.bottom.balloons[target].isAlive, isFalse);
      runUntil(c, () => c.top.runStatus == RunStatus.ready);
    }
  });

  test('bot vs bot: a full game always resolves', () {
    for (var seed = 1; seed <= 4; seed++) {
      final config = GameConfig(obstacleSeed: seed);
      final c = GameController(
        config: config,
        bottomAgent: BotController(difficulty: BotDifficulty.hard, seed: seed),
        topAgent: BotController(
          difficulty: BotDifficulty.easy,
          seed: seed + 100,
        ),
      );
      runUntil(c, () => c.phase.value == GamePhase.gameOver, maxSeconds: 400);
      expect(c.phase.value, GamePhase.gameOver);
      final result = c.result.value!;
      expect(result.outcome.winner, isNotNull);
    }
  });
}
