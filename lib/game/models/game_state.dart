/// Global phase of a match. Owned exclusively by the GameController.
enum GamePhase {
  /// "Round 1" banner before the very first countdown.
  intro,

  /// 3-2-1 before players may move.
  countdown,

  /// Both players racing through the dots.
  playing,

  /// A player crossed; showing their run summary.
  playerSuccess,

  /// The crossing player is choosing an opponent balloon.
  targeting,

  /// The chosen balloon is popping.
  balloonDestroyed,

  /// Board is being reset for the next round.
  nextRound,

  /// Match finished; result is available.
  gameOver,
}

/// Per-player state of the current run. Players race simultaneously, so a
/// failure is tracked per player rather than as a global phase.
enum RunStatus {
  /// At the start point, waiting to move.
  ready,

  /// Drawing through the field.
  running,

  /// The run failed; the failure animation plays before resetting.
  failed,

  /// Reached the opponent's side.
  finished,

  /// Round ended before this player finished.
  halted,

  /// No attempts left; sits out for the rest of the match.
  eliminated,
}

enum FailureReason { outOfInk, penLifted }

extension FailureReasonText on FailureReason {
  String get title => switch (this) {
    FailureReason.outOfInk => 'OUT OF INK!',
    FailureReason.penLifted => 'PEN LIFTED!',
  };

  String get description => switch (this) {
    FailureReason.outOfInk => 'The pen ran dry before reaching the other side.',
    FailureReason.penLifted => 'Keep your finger down while drawing.',
  };
}

/// Why the match ended / how the winner was decided.
enum WinReason {
  allBalloonsDestroyed,
  moreBalloonsDestroyed,
  higherScore,
  longerDistance,
  draw,
}

extension WinReasonText on WinReason {
  String get description => switch (this) {
    WinReason.allBalloonsDestroyed => 'All opponent balloons destroyed',
    WinReason.moreBalloonsDestroyed => 'Time up — more balloons destroyed',
    WinReason.higherScore => 'Time up — balloons tied, higher total score',
    WinReason.longerDistance => 'Time up — score tied, longer total distance',
    WinReason.draw => 'Time up — everything tied',
  };
}

/// What ended the match.
enum GameEndTrigger { balloons, timer, noAttempts }
