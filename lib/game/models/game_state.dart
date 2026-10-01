/// Global phase of a match. Owned exclusively by the GameController.
///
/// The match is one continuous race: there are no rounds. Players keep
/// drawing, popping balloons and respawning until the clock runs out or one
/// side has no balloons left.
enum GamePhase {
  /// "READY?" banner before the countdown.
  intro,

  /// 3-2-1 before players may move.
  countdown,

  /// Both players racing through the dots and hunting balloons.
  playing,

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

  /// Popped an opponent balloon; the pen respawns at its start shortly.
  finished,

  /// The match ended while this run was in progress.
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
    WinReason.moreBalloonsDestroyed => 'More balloons destroyed',
    WinReason.higherScore => 'Balloons tied — higher total score',
    WinReason.longerDistance => 'Score tied — longer total distance',
    WinReason.draw => 'Balloons, score and distance all tied',
  };
}

/// What ended the match.
enum GameEndTrigger { balloons, timer, noAttempts }

extension GameEndTriggerText on GameEndTrigger {
  String get headline => switch (this) {
    GameEndTrigger.balloons => 'All balloons popped',
    GameEndTrigger.timer => "Time's up",
    GameEndTrigger.noAttempts => 'No attempts left',
  };
}
