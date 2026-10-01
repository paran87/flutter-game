import 'dart:ui';

import 'game_state.dart';

/// One player's final line on the result screen.
class ResultLine {
  const ResultLine({
    required this.name,
    required this.color,
    required this.isBot,
    required this.balloonsDestroyed,
    required this.balloonsStanding,
    required this.score,
    required this.distance,
    required this.penalties,
    required this.successfulRuns,
    required this.failedRuns,
  });

  final String name;
  final Color color;
  final bool isBot;
  final int balloonsDestroyed;
  final int balloonsStanding;
  final int score;
  final int distance;
  final int penalties;
  final int successfulRuns;
  final int failedRuns;
}

/// Who won and why.
class GameOutcome {
  const GameOutcome(this.winner, this.reason);

  /// Index of the winning line (0 = bottom/Player 1, 1 = top/Player 2), or
  /// null for a draw.
  final int? winner;
  final WinReason reason;

  bool get isDraw => winner == null;
}

/// Everything the result screen needs, detached from the live game.
class GameResult {
  const GameResult({
    required this.bottom,
    required this.top,
    required this.outcome,
    required this.trigger,
    required this.rounds,
  });

  final ResultLine bottom;
  final ResultLine top;
  final GameOutcome outcome;
  final GameEndTrigger trigger;
  final int rounds;

  ResultLine? get winnerLine => switch (outcome.winner) {
    0 => bottom,
    1 => top,
    _ => null,
  };
}
