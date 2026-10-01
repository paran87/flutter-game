import 'dart:ui';

import '../models/game_config.dart';
import '../models/obstacle_dot.dart';
import '../utils/collision_utils.dart';

/// Tracks one player's contact with dots and decides when a touch costs
/// points.
///
/// Rules (all tunable in [GameConfig]):
///  * Touching a dot never stops the pen.
///  * A touch is penalised once, when the pen *enters* a dot. Staying in
///    contact for many frames does not repeat the penalty.
///  * After a penalty the same dot is on cooldown
///    ([GameConfig.collisionPenaltyCooldown]); brushing it again within that
///    window (e.g. jittering along its edge) costs nothing.
///  * Different dots are independent, so ploughing through a dense cluster
///    costs one penalty per dot.
class CollisionController {
  CollisionController(this.config);

  final GameConfig config;

  /// Dots the pen overlapped on the previous step.
  Set<int> _touching = {};

  /// Time (s) each dot last penalised this player.
  final Map<int, double> _lastPenaltyAt = {};

  /// Whether the pen currently overlaps any dot.
  bool get isTouching => _touching.isNotEmpty;

  /// Dot ids currently in contact (for debug display).
  Set<int> get touching => _touching;

  /// Sweeps the pen from [from] to [to] at game time [now] (seconds) and
  /// returns the dots that should be penalised for this step.
  List<ObstacleDot> step(
    ObstacleField field,
    Offset from,
    Offset to,
    double now,
  ) {
    final penRadius = config.playerRadius;
    final area = Rect.fromPoints(from, to).inflate(penRadius + field.maxRadius);
    final current = <int>{};
    final penalised = <ObstacleDot>[];
    final cooldown = config.collisionPenaltyCooldown.inMicroseconds / 1e6;

    for (final id in field.candidatesIn(area)) {
      final dot = field.dots[id];
      final hit = sweptCircleHits(
        from: from,
        to: to,
        penRadius: penRadius,
        center: dot.center,
        radius: dot.radius,
        tolerance: config.collisionTolerance,
      );
      if (!hit) continue;
      current.add(id);
      final entering = !_touching.contains(id);
      final last = _lastPenaltyAt[id];
      final cooledDown = last == null || now - last >= cooldown;
      if (entering && cooledDown) {
        _lastPenaltyAt[id] = now;
        penalised.add(dot);
      }
    }
    _touching = current;
    return penalised;
  }

  /// Clears contact state for a new run.
  void reset() {
    _touching = {};
    _lastPenaltyAt.clear();
  }
}
