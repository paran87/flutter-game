enum BalloonStatus {
  /// Floating and alive.
  intact,

  /// Selected by an attacker; the pop animation is about to play.
  targeted,

  /// Pop animation is playing.
  popping,

  /// Gone for the rest of the game.
  destroyed,
}

class Balloon {
  Balloon(this.index);

  /// Slot index (0 = left).
  final int index;
  BalloonStatus status = BalloonStatus.intact;

  /// True while the balloon can still be attacked.
  bool get isAlive => status == BalloonStatus.intact;

  /// True while the balloon still counts for its owner.
  bool get isStanding => status != BalloonStatus.destroyed;
}
