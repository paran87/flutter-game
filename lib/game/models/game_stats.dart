/// Values for the run currently in progress.
class RunStats {
  /// Path length of the current run in displayed distance units.
  double distance = 0;

  /// Points lost to obstacles during the current run.
  int penalties = 0;

  /// Number of obstacle touches during the current run.
  int collisions = 0;

  void reset() {
    distance = 0;
    penalties = 0;
    collisions = 0;
  }
}

/// Cumulative statistics for one player across the whole game.
class PlayerStats {
  /// Distance of all finished/failed/interrupted runs (display units).
  double totalDistance = 0;

  /// Score banked from successful (or interrupted, if configured) runs.
  int bankedScore = 0;

  /// Every penalty point ever deducted.
  int totalPenalties = 0;
  int totalCollisions = 0;
  int successfulRuns = 0;
  int failedRuns = 0;
  int balloonsDestroyed = 0;
}

/// Summary of a single completed run, shown in the "RUN COMPLETE" card.
class RunSummary {
  const RunSummary({
    required this.distancePoints,
    required this.penalties,
    required this.runScore,
    required this.collisions,
  });

  final int distancePoints;
  final int penalties;
  final int runScore;
  final int collisions;
}
