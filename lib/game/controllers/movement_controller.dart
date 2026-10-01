import 'dart:math' as math;
import 'dart:ui';

import '../models/game_config.dart';

/// Moves a pen toward its target with frame-rate independent easing and a
/// hard speed cap. Shared by every player so the bot obeys the same physics
/// as the human.
class MovementController {
  const MovementController(this.config);

  final GameConfig config;

  /// Returns the new position after moving from [position] toward [target]
  /// for [dt] seconds.
  ///
  /// * Exponential smoothing (`1 - e^(-k·dt)`) makes the pen glide rather
  ///   than snap, and behaves the same at 30, 60 or 120 fps.
  /// * The step is clamped to `speed · dt`, where speed is the agent's cap
  ///   (bounded by [GameConfig.maximumMovementSpeed]) times [speedFactor]
  ///   (e.g. the brief slowdown after touching a dot).
  /// * The result is kept inside the playable area.
  Offset step({
    required Offset position,
    required Offset target,
    required double dt,
    required double maxSpeed,
    double speedFactor = 1,
  }) {
    final alpha = 1 - math.exp(-config.movementSmoothing * dt);
    var delta = (target - position) * alpha;
    final speed = math.min(maxSpeed, config.maximumMovementSpeed) * speedFactor;
    final maxStep = speed * dt;
    final length = delta.distance;
    if (length > maxStep && length > 0) {
      delta = delta * (maxStep / length);
    }
    return clampToPlayArea(position + delta);
  }

  /// Keeps a pen fully inside the board.
  Offset clampToPlayArea(Offset p) {
    final r = config.playerRadius;
    return Offset(
      p.dx.clamp(r, config.worldWidth - r),
      p.dy.clamp(r, config.worldHeight - r),
    );
  }
}
