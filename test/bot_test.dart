import 'package:dotline_duel/game/controllers/bot_controller.dart';
import 'package:dotline_duel/game/controllers/game_controller.dart';
import 'package:dotline_duel/game/controllers/player_agent.dart';
import 'package:dotline_duel/game/models/game_config.dart';
import 'package:dotline_duel/game/models/game_state.dart';
import 'package:dotline_duel/game/utils/distance_utils.dart';
import 'package:dotline_duel/game/utils/path_utils.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/sim.dart';

/// Crossing stats for one bot run on a given seed.
({double seconds, int penalties, double inkUsed, double pathRatio}) crossOnce(
  BotDifficulty difficulty,
  int seed,
) {
  final config = GameConfig(obstacleSeed: seed, botDifficulty: difficulty);
  final bot = BotController(difficulty: difficulty, seed: seed);
  final c = skipToPlaying(
    GameController(config: config, bottomAgent: IdleAgent(), topAgent: bot),
  );
  final start = c.time;
  runUntil(c, () => c.phase.value != GamePhase.playing, maxSeconds: 20);
  final success = c.lastSuccess.value;
  expect(success, isNotNull, reason: '$difficulty bot must cross (seed $seed)');
  expect(success!.player, c.top);
  final straight = config.topGoalY - config.topStart.dy;
  final distanceWorld =
      success.summary.distancePoints / config.distanceUnitsPerWorldUnit;
  return (
    seconds: c.time - start,
    penalties: success.summary.penalties,
    inkUsed: distanceWorld / config.inkCapacity,
    pathRatio: distanceWorld / straight,
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

  test('bot picks an available balloon after a short aiming delay', () {
    final bot = BotController(difficulty: BotDifficulty.normal, seed: 1);
    final delay = bot.profile.targetDelay;
    expect(bot.chooseBalloon([0, 2], delay * 0.5), isNull);
    expect([0, 2], contains(bot.chooseBalloon([0, 2], delay + 0.01)));
    expect(bot.chooseBalloon([], 99), isNull);
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
