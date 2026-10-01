import 'dart:ui';

/// Bot skill levels. See [BotProfile] for what each level changes.
enum BotDifficulty { easy, normal, hard }

extension BotDifficultyLabel on BotDifficulty {
  String get label => switch (this) {
    BotDifficulty.easy => 'Easy',
    BotDifficulty.normal => 'Normal',
    BotDifficulty.hard => 'Hard',
  };
}

/// Tuning values for one bot difficulty.
class BotProfile {
  const BotProfile({
    required this.speed,
    required this.obstacleAvoidance,
    required this.pathNoise,
    required this.wobbleAmplitude,
    required this.wobbleFrequency,
    required this.targetDelay,
    required this.reactionDelay,
  });

  /// Maximum pen speed in world units per second.
  final double speed;

  /// How strongly the pathfinder avoids dots (0 = ignores them).
  final double obstacleAvoidance;

  /// Random cost noise added to the path grid (higher = less efficient paths).
  final double pathNoise;

  /// Sideways hand wobble while following the path, in world units.
  final double wobbleAmplitude;

  /// Wobble oscillations per second.
  final double wobbleFrequency;

  /// Seconds the bot "thinks" before picking a balloon to attack.
  final double targetDelay;

  /// Seconds the bot waits after GO before it starts drawing.
  final double reactionDelay;
}

/// Every gameplay constant lives here so the game can be tuned in one place.
///
/// Spatial values are in *world units*. The board is a fixed
/// [worldWidth] × [worldHeight] world that is uniformly scaled to the screen,
/// so gameplay is identical on every device.
class GameConfig {
  const GameConfig({
    // Match
    this.gameDuration = const Duration(seconds: 120),
    this.balloonsPerPlayer = 3,
    this.attemptsPerPlayer = 3,
    this.timerWarningSeconds = 30,
    this.timerCriticalSeconds = 10,
    // World layout
    this.worldWidth = 1000,
    this.worldHeight = 1600,
    this.fieldRect = const Rect.fromLTRB(22, 270, 978, 1330),
    this.topStart = const Offset(500, 205),
    this.bottomStart = const Offset(500, 1395),
    this.topGoalY = 1395,
    this.bottomGoalY = 205,
    this.topBalloonY = 82,
    this.bottomBalloonY = 1518,
    this.balloonSpacing = 250,
    // Movement
    this.touchOffset = 76,
    this.movementSmoothing = 14,
    this.playerSpeed = 560,
    this.maximumMovementSpeed = 620,
    this.playerRadius = 12,
    this.minTracePointSpacing = 2.5,
    this.runStartThreshold = 4,
    // Obstacles
    this.obstacleSeed,
    this.obstacleDensity = 1.0,
    this.baseObstacleCount = 680,
    this.minObstacleRadius = 3.2,
    this.maxObstacleRadius = 16,
    this.minObstacleOpacity = 0.18,
    this.maxObstacleOpacity = 1.0,
    this.lightDotChance = 0.22,
    this.minObstacleSpacing = 2.5,
    this.mediumObstacleRadius = 6.5,
    this.largeObstacleRadius = 10.5,
    // Collision & penalties
    this.collisionTolerance = 2,
    this.smallObstaclePenalty = 5,
    this.mediumObstaclePenalty = 10,
    this.largeObstaclePenalty = 20,
    this.collisionPenaltyCooldown = const Duration(milliseconds: 300),
    this.collisionSlowdownFactor = 0.55,
    this.collisionSlowdownDuration = const Duration(milliseconds: 180),
    // Scoring
    this.distanceUnitsPerWorldUnit = 0.6,
    this.minimumScore = 0,
    this.bankInterruptedRunScore = false,
    // Runs
    this.inkCapacity = 2500,
    this.penLiftFailsRun = true,
    this.penLiftGracePeriod = const Duration(milliseconds: 1500),
    // Trace rendering
    this.traceWidth = 4.0,
    this.traceOpacity = 0.9,
    this.traceJitter = 0.8,
    // Phase timings
    this.introDuration = const Duration(milliseconds: 1300),
    this.countdownStep = const Duration(milliseconds: 650),
    this.countdownSteps = 3,
    this.successSummaryDuration = const Duration(milliseconds: 1900),
    this.targetingDuration = const Duration(seconds: 8),
    this.balloonAnimationDuration = const Duration(milliseconds: 800),
    this.postPopPause = const Duration(milliseconds: 500),
    this.nextRoundDuration = const Duration(milliseconds: 1200),
    this.failureResetDuration = const Duration(milliseconds: 1000),
    this.gameOverDelay = const Duration(milliseconds: 1600),
    // Bot
    this.botDifficulty = BotDifficulty.normal,
    this.botPathCellSize = 20,
  });

  // ---------------------------------------------------------------- Match
  final Duration gameDuration;
  final int balloonsPerPlayer;
  final int attemptsPerPlayer;
  final int timerWarningSeconds;
  final int timerCriticalSeconds;

  // --------------------------------------------------------- World layout
  final double worldWidth;
  final double worldHeight;

  /// Area that is filled with obstacle dots. It spans the whole playable
  /// width (pens are clamped to it horizontally) so there is no free lane
  /// around the field.
  final Rect fieldRect;

  /// Where the top player (Player 2) starts each run.
  final Offset topStart;

  /// Where the bottom player (Player 1) starts each run.
  final Offset bottomStart;

  /// The top player succeeds when it reaches y >= [topGoalY].
  final double topGoalY;

  /// The bottom player succeeds when it reaches y <= [bottomGoalY].
  final double bottomGoalY;

  final double topBalloonY;
  final double bottomBalloonY;
  final double balloonSpacing;

  // ------------------------------------------------------------- Movement
  /// Distance (logical pixels) the marker sits above the finger.
  final double touchOffset;

  /// Exponential easing rate toward the target (higher = snappier).
  final double movementSmoothing;

  /// Comfortable cruising speed of the human pen (world units / s).
  final double playerSpeed;

  /// Hard speed cap for any pen (world units / s).
  final double maximumMovementSpeed;

  /// Collision radius of a player marker.
  final double playerRadius;

  /// A new trace point is stored once the pen moved at least this far.
  final double minTracePointSpacing;

  /// Movement needed from the start point before a run "starts".
  final double runStartThreshold;

  // ------------------------------------------------------------ Obstacles
  /// Fixed seed for reproducible layouts. `null` = random each game.
  final int? obstacleSeed;

  /// Multiplier on [baseObstacleCount].
  final double obstacleDensity;
  final int baseObstacleCount;
  final double minObstacleRadius;
  final double maxObstacleRadius;
  final double minObstacleOpacity;
  final double maxObstacleOpacity;

  /// Chance that a dot is a lighter gray dot.
  final double lightDotChance;

  /// Minimum gap between two dot edges.
  final double minObstacleSpacing;

  /// Dots with radius >= this are "medium".
  final double mediumObstacleRadius;

  /// Dots with radius >= this are "large".
  final double largeObstacleRadius;

  int get obstacleCount => (baseObstacleCount * obstacleDensity).round();
  double get fieldWidth => fieldRect.width;
  double get fieldHeight => fieldRect.height;

  // -------------------------------------------------- Collision / penalty
  /// Overlap (world units) forgiven before a touch counts.
  final double collisionTolerance;
  final int smallObstaclePenalty;
  final int mediumObstaclePenalty;
  final int largeObstaclePenalty;

  /// A dot can only penalise the same player again after this cooldown.
  final Duration collisionPenaltyCooldown;

  /// Pen speed multiplier right after touching a dot.
  final double collisionSlowdownFactor;
  final Duration collisionSlowdownDuration;

  // -------------------------------------------------------------- Scoring
  /// Converts world path length into displayed distance / points.
  final double distanceUnitsPerWorldUnit;
  final int minimumScore;

  /// Whether a run cut short by the opponent's crossing still banks points.
  final bool bankInterruptedRunScore;

  // ----------------------------------------------------------------- Runs
  /// Maximum path length (world units) per run before the pen runs dry.
  final double inkCapacity;
  final bool penLiftFailsRun;
  final Duration penLiftGracePeriod;

  // ---------------------------------------------------------------- Trace
  /// Ballpoint stroke width in world units.
  final double traceWidth;
  final double traceOpacity;

  /// Maximum hand-jitter applied when rendering a trace (world units).
  final double traceJitter;

  // -------------------------------------------------------- Phase timings
  final Duration introDuration;
  final Duration countdownStep;
  final int countdownSteps;
  final Duration successSummaryDuration;
  final Duration targetingDuration;
  final Duration balloonAnimationDuration;
  final Duration postPopPause;
  final Duration nextRoundDuration;
  final Duration failureResetDuration;
  final Duration gameOverDelay;

  // ------------------------------------------------------------------ Bot
  final BotDifficulty botDifficulty;

  /// Grid resolution used by the bot's pathfinder.
  final double botPathCellSize;

  BotProfile get botProfile => botProfileFor(botDifficulty);

  static BotProfile botProfileFor(BotDifficulty difficulty) =>
      switch (difficulty) {
        BotDifficulty.easy => const BotProfile(
          speed: 270,
          obstacleAvoidance: 0.9,
          pathNoise: 2.2,
          wobbleAmplitude: 15,
          wobbleFrequency: 0.9,
          targetDelay: 1.4,
          reactionDelay: 0.7,
        ),
        BotDifficulty.normal => const BotProfile(
          speed: 360,
          obstacleAvoidance: 4,
          pathNoise: 0.8,
          wobbleAmplitude: 8,
          wobbleFrequency: 0.7,
          targetDelay: 1.0,
          reactionDelay: 0.45,
        ),
        BotDifficulty.hard => const BotProfile(
          speed: 460,
          obstacleAvoidance: 10,
          pathNoise: 0.15,
          wobbleAmplitude: 3,
          wobbleFrequency: 0.5,
          targetDelay: 0.7,
          reactionDelay: 0.25,
        ),
      };

  /// Total ink in displayed distance units.
  double get inkCapacityDistance => inkCapacity * distanceUnitsPerWorldUnit;

  /// Horizontal positions of the three balloon slots.
  List<double> balloonXs(int count) {
    final center = worldWidth / 2;
    final start = center - balloonSpacing * (count - 1) / 2;
    return [for (var i = 0; i < count; i++) start + balloonSpacing * i];
  }

  GameConfig copyWith({
    Duration? gameDuration,
    BotDifficulty? botDifficulty,
    int? obstacleSeed,
    double? obstacleDensity,
    double? touchOffset,
    double? inkCapacity,
    bool? penLiftFailsRun,
  }) {
    return GameConfig(
      gameDuration: gameDuration ?? this.gameDuration,
      balloonsPerPlayer: balloonsPerPlayer,
      attemptsPerPlayer: attemptsPerPlayer,
      timerWarningSeconds: timerWarningSeconds,
      timerCriticalSeconds: timerCriticalSeconds,
      worldWidth: worldWidth,
      worldHeight: worldHeight,
      fieldRect: fieldRect,
      topStart: topStart,
      bottomStart: bottomStart,
      topGoalY: topGoalY,
      bottomGoalY: bottomGoalY,
      topBalloonY: topBalloonY,
      bottomBalloonY: bottomBalloonY,
      balloonSpacing: balloonSpacing,
      touchOffset: touchOffset ?? this.touchOffset,
      movementSmoothing: movementSmoothing,
      playerSpeed: playerSpeed,
      maximumMovementSpeed: maximumMovementSpeed,
      playerRadius: playerRadius,
      minTracePointSpacing: minTracePointSpacing,
      runStartThreshold: runStartThreshold,
      obstacleSeed: obstacleSeed ?? this.obstacleSeed,
      obstacleDensity: obstacleDensity ?? this.obstacleDensity,
      baseObstacleCount: baseObstacleCount,
      minObstacleRadius: minObstacleRadius,
      maxObstacleRadius: maxObstacleRadius,
      minObstacleOpacity: minObstacleOpacity,
      maxObstacleOpacity: maxObstacleOpacity,
      lightDotChance: lightDotChance,
      minObstacleSpacing: minObstacleSpacing,
      mediumObstacleRadius: mediumObstacleRadius,
      largeObstacleRadius: largeObstacleRadius,
      collisionTolerance: collisionTolerance,
      smallObstaclePenalty: smallObstaclePenalty,
      mediumObstaclePenalty: mediumObstaclePenalty,
      largeObstaclePenalty: largeObstaclePenalty,
      collisionPenaltyCooldown: collisionPenaltyCooldown,
      collisionSlowdownFactor: collisionSlowdownFactor,
      collisionSlowdownDuration: collisionSlowdownDuration,
      distanceUnitsPerWorldUnit: distanceUnitsPerWorldUnit,
      minimumScore: minimumScore,
      bankInterruptedRunScore: bankInterruptedRunScore,
      inkCapacity: inkCapacity ?? this.inkCapacity,
      penLiftFailsRun: penLiftFailsRun ?? this.penLiftFailsRun,
      penLiftGracePeriod: penLiftGracePeriod,
      traceWidth: traceWidth,
      traceOpacity: traceOpacity,
      traceJitter: traceJitter,
      introDuration: introDuration,
      countdownStep: countdownStep,
      countdownSteps: countdownSteps,
      successSummaryDuration: successSummaryDuration,
      targetingDuration: targetingDuration,
      balloonAnimationDuration: balloonAnimationDuration,
      postPopPause: postPopPause,
      nextRoundDuration: nextRoundDuration,
      failureResetDuration: failureResetDuration,
      gameOverDelay: gameOverDelay,
      botDifficulty: botDifficulty ?? this.botDifficulty,
      botPathCellSize: botPathCellSize,
    );
  }
}
