import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'balloon.dart';
import 'game_state.dart';
import 'game_stats.dart';
import 'ink_trace.dart';

/// Which end of the board a player starts from.
enum PlayerSide {
  /// Player 1. Starts at the bottom and races upward.
  bottom,

  /// Player 2. Starts at the top and races downward.
  top,
}

/// Static presentation data for a player.
class PlayerIdentity {
  const PlayerIdentity({
    required this.name,
    required this.tag,
    required this.color,
    required this.lightColor,
    required this.isBot,
  });

  /// Display name, e.g. "YOU" or "BOT".
  final String name;

  /// Short label, e.g. "P1".
  final String tag;

  /// Marker, trace and balloon colour.
  final Color color;
  final Color lightColor;
  final bool isBot;
}

/// Everything the HUD shows about a player, as a value object so that
/// listeners are only notified when something visible actually changes.
@immutable
class PlayerHudSnapshot {
  const PlayerHudSnapshot({
    required this.score,
    required this.totalDistance,
    required this.runDistance,
    required this.runPenalties,
    required this.attempts,
    required this.maxAttempts,
    required this.balloonsStanding,
    required this.balloonsDestroyed,
    required this.inkPercent,
    required this.runStatus,
  });

  final int score;
  final int totalDistance;
  final int runDistance;
  final int runPenalties;
  final int attempts;
  final int maxAttempts;
  final int balloonsStanding;
  final int balloonsDestroyed;
  final int inkPercent;
  final RunStatus runStatus;

  @override
  bool operator ==(Object other) =>
      other is PlayerHudSnapshot &&
      other.score == score &&
      other.totalDistance == totalDistance &&
      other.runDistance == runDistance &&
      other.runPenalties == runPenalties &&
      other.attempts == attempts &&
      other.maxAttempts == maxAttempts &&
      other.balloonsStanding == balloonsStanding &&
      other.balloonsDestroyed == balloonsDestroyed &&
      other.inkPercent == inkPercent &&
      other.runStatus == runStatus;

  @override
  int get hashCode => Object.hash(
    score,
    totalDistance,
    runDistance,
    runPenalties,
    attempts,
    maxAttempts,
    balloonsStanding,
    balloonsDestroyed,
    inkPercent,
    runStatus,
  );
}

/// Mutable game-time state of one player. Only the GameController mutates it.
class Player {
  Player({
    required this.side,
    required this.identity,
    required this.startPosition,
    required int balloons,
    required this.maxAttempts,
  }) : position = startPosition,
       attemptsRemaining = maxAttempts,
       balloons = List.generate(balloons, Balloon.new),
       trace = InkTrace(id: _nextTraceId++, start: startPosition);

  static int _nextTraceId = 0;

  final PlayerSide side;
  final PlayerIdentity identity;
  final Offset startPosition;
  final int maxAttempts;
  final List<Balloon> balloons;

  final RunStats run = RunStats();
  final PlayerStats stats = PlayerStats();

  Offset position;
  InkTrace trace;
  RunStatus runStatus = RunStatus.ready;
  FailureReason? failureReason;
  int attemptsRemaining;

  /// Seconds of collision slowdown still active.
  double slowdownRemaining = 0;

  /// Seconds of marker shake still active.
  double shakeRemaining = 0;

  /// Seconds the pen has been lifted during a running run.
  double penLiftedFor = 0;

  /// Seconds spent in the current [runStatus] (used for failure animation).
  double statusTime = 0;

  late final ValueNotifier<PlayerHudSnapshot> hud = ValueNotifier(
    _snapshot(0, 1),
  );

  bool get isTop => side == PlayerSide.top;
  bool get canMove =>
      runStatus == RunStatus.ready || runStatus == RunStatus.running;
  int get balloonsStanding => balloons.where((b) => b.isStanding).length;
  List<int> get aliveBalloonIndexes => [
    for (final b in balloons)
      if (b.isAlive) b.index,
  ];

  /// Replaces the trace with an empty one at the start position (the old
  /// trace object can then fade out independently).
  void beginFreshTrace() {
    trace = InkTrace(id: _nextTraceId++, start: startPosition);
  }

  /// Starts a fresh run trace at the start position.
  void resetToStart() {
    position = startPosition;
    trace = InkTrace(id: _nextTraceId++, start: startPosition);
    run.reset();
    runStatus = attemptsRemaining > 0 ? RunStatus.ready : RunStatus.eliminated;
    failureReason = null;
    slowdownRemaining = 0;
    shakeRemaining = 0;
    penLiftedFor = 0;
    statusTime = 0;
  }

  /// Publishes the HUD snapshot; listeners fire only on visible changes.
  void publishHud({required int liveScore, required double inkFraction}) {
    hud.value = _snapshot(liveScore, inkFraction);
  }

  PlayerHudSnapshot _snapshot(int liveScore, double inkFraction) {
    return PlayerHudSnapshot(
      score: liveScore,
      totalDistance: (stats.totalDistance + run.distance).round(),
      runDistance: run.distance.round(),
      runPenalties: run.penalties,
      attempts: attemptsRemaining,
      maxAttempts: maxAttempts,
      balloonsStanding: balloonsStanding,
      balloonsDestroyed: stats.balloonsDestroyed,
      inkPercent: (inkFraction.clamp(0.0, 1.0) * 100).round(),
      runStatus: runStatus,
    );
  }

  void dispose() => hud.dispose();
}
