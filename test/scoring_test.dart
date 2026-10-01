import 'package:dotline_duel/game/controllers/scoring_controller.dart';
import 'package:dotline_duel/game/models/game_config.dart';
import 'package:dotline_duel/game/models/obstacle_dot.dart';
import 'package:dotline_duel/game/models/player.dart';
import 'package:dotline_duel/game/models/player_identities.dart';
import 'package:flutter_test/flutter_test.dart';

Player newPlayer(GameConfig config) => Player(
  side: PlayerSide.bottom,
  identity: humanIdentity,
  startPosition: config.bottomStart,
  balloons: 3,
  maxAttempts: 3,
);

ObstacleDot dot(ObstacleSize size) =>
    ObstacleDot(id: 0, center: Offset.zero, radius: 5, opacity: 1, size: size);

void main() {
  const config = GameConfig();
  const scoring = ScoringController(config);

  test('penalties come from config by dot size', () {
    expect(scoring.penaltyFor(ObstacleSize.small), config.smallObstaclePenalty);
    expect(
      scoring.penaltyFor(ObstacleSize.medium),
      config.mediumObstaclePenalty,
    );
    expect(scoring.penaltyFor(ObstacleSize.large), config.largeObstaclePenalty);
  });

  test('run score = distance - penalties (spec example 800 - 30 = 770)', () {
    expect(scoring.runScore(800, 30), 770);
  });

  test('score never drops below the configured minimum', () {
    expect(scoring.runScore(20, 100), config.minimumScore);
    const harsh = ScoringController(GameConfig(minimumScore: 0));
    expect(harsh.runScore(0, 500), 0);
  });

  test('longer risky route can beat a short safe one (risk/reward)', () {
    expect(scoring.runScore(900, 100), greaterThan(scoring.runScore(700, 10)));
  });

  test('applyPenalty updates run and lifetime stats', () {
    final p = newPlayer(config);
    scoring.applyPenalty(p, dot(ObstacleSize.large));
    scoring.applyPenalty(p, dot(ObstacleSize.small));
    expect(p.run.penalties, 25);
    expect(p.run.collisions, 2);
    expect(p.stats.totalPenalties, 25);
  });

  test('closing a successful run banks score and distance', () {
    final p = newPlayer(config)..run.distance = 820;
    p.run.penalties = 30;
    final summary = scoring.closeRun(p, bank: true);
    expect(summary.runScore, 790);
    expect(p.stats.bankedScore, 790);
    expect(p.stats.totalDistance, 820);
    expect(p.run.distance, 0);
  });

  test('closing a failed run keeps distance but forfeits score', () {
    final p = newPlayer(config)..run.distance = 400;
    scoring.closeRun(p, bank: false);
    expect(p.stats.bankedScore, 0);
    expect(p.stats.totalDistance, 400);
  });

  test('live score = banked + current run, clamped', () {
    final p = newPlayer(config)..stats.bankedScore = 500;
    p.run.distance = 100;
    p.run.penalties = 300; // run score clamps to 0, banked score is kept
    expect(scoring.liveScore(p), 500);
  });
}
