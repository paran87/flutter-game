import 'dart:math' as math;

import '../models/game_config.dart';
import '../models/game_stats.dart';
import '../models/obstacle_dot.dart';
import '../models/player.dart';

/// Pure scoring rules.
///
///   run score  = distance − obstacle penalties   (never below minimumScore)
///   live score = banked score + current run score
///
/// Distance is the cumulative path length (see `pathLength`), converted to
/// display units, so long winding routes earn more — but every dot touched
/// along the way costs points. That is the game's core risk/reward.
class ScoringController {
  const ScoringController(this.config);

  final GameConfig config;

  int penaltyFor(ObstacleSize size) => switch (size) {
    ObstacleSize.small => config.smallObstaclePenalty,
    ObstacleSize.medium => config.mediumObstaclePenalty,
    ObstacleSize.large => config.largeObstaclePenalty,
  };

  /// World units → displayed distance units.
  double distanceFromWorld(double worldLength) =>
      worldLength * config.distanceUnitsPerWorldUnit;

  int runScore(double distance, int penalties) =>
      math.max(config.minimumScore, distance.round() - penalties);

  int liveScore(Player p) => math.max(
    config.minimumScore,
    p.stats.bankedScore + runScore(p.run.distance, p.run.penalties),
  );

  /// Records an obstacle touch against the current run.
  int applyPenalty(Player p, ObstacleDot dot) {
    final penalty = penaltyFor(dot.size);
    p.run.penalties += penalty;
    p.run.collisions++;
    p.stats.totalPenalties += penalty;
    p.stats.totalCollisions++;
    return penalty;
  }

  /// Ends the current run. The distance always counts toward total distance;
  /// the run score is only banked when [bank] is true (successful crossing,
  /// or an interrupted run if configured).
  RunSummary closeRun(Player p, {required bool bank}) {
    final summary = RunSummary(
      distancePoints: p.run.distance.round(),
      penalties: p.run.penalties,
      runScore: runScore(p.run.distance, p.run.penalties),
      collisions: p.run.collisions,
    );
    p.stats.totalDistance += p.run.distance;
    if (bank) p.stats.bankedScore += summary.runScore;
    p.run.reset();
    return summary;
  }
}
