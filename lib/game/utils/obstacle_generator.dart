import 'dart:math' as math;
import 'dart:ui';

import '../models/game_config.dart';
import '../models/obstacle_dot.dart';

/// Classifies a dot radius into its penalty tier.
ObstacleSize obstacleSizeFor(double radius, GameConfig config) {
  if (radius >= config.largeObstacleRadius) return ObstacleSize.large;
  if (radius >= config.mediumObstacleRadius) return ObstacleSize.medium;
  return ObstacleSize.small;
}

/// Generates a dense, evenly populated, seeded dot field.
///
/// * Every dot is one of three clear sizes — small, medium or large — in the
///   configured shares, with a little jitter so it still looks hand-inked.
/// * All dots are dark ink (no faint grey specks).
/// * Placement uses "best candidate" sampling: each dot tries several random
///   spots and keeps the one furthest from its neighbours. That packs the
///   field evenly with no empty patches or corridors, yet never looks like a
///   grid. Big dots are placed first so they always find room.
/// * Only the top and bottom edges are slightly ragged, like the reference
///   sketch; the sides stay full so there is no free lane around the dots.
class ObstacleGenerator {
  ObstacleGenerator(this.config);

  final GameConfig config;

  /// Random spots tried per dot; the most open one wins.
  static const _candidates = 8;

  /// Spots tried before giving up on a dot that no longer fits.
  static const _maxTries = 60;

  ObstacleField generate(int seed) {
    final rng = math.Random(seed);
    final field = config.fieldRect;
    final edge = _Edge(field, rng.nextDouble() * 100);
    final target = config.obstacleCount;

    // Decide every dot's size up front, biggest first.
    final radii = <double>[for (var i = 0; i < target; i++) _tierRadius(rng)]
      ..sort((a, b) => b.compareTo(a));

    final dots = <ObstacleDot>[];
    const cell = 32.0;
    final cols = (field.width / cell).ceil() + 1;
    final rows = (field.height / cell).ceil() + 1;
    final grid = List.generate(cols * rows, (_) => <int>[]);
    int col(double x) => ((x - field.left) / cell).floor().clamp(0, cols - 1);
    int row(double y) => ((y - field.top) / cell).floor().clamp(0, rows - 1);

    for (final radius in radii) {
      Offset? best;
      var bestGap = -1.0;
      var found = 0;
      for (var t = 0; t < _maxTries && found < _candidates; t++) {
        final p = Offset(
          field.left + rng.nextDouble() * field.width,
          field.top + rng.nextDouble() * field.height,
        );
        if (rng.nextDouble() > edge.at(p)) continue;
        final gap = _gapAt(p, radius, dots, grid, cols, col, row);
        if (gap < config.minObstacleSpacing) continue;
        found++;
        if (gap > bestGap) {
          bestGap = gap;
          best = p;
        }
      }
      if (best == null) continue;

      final blobAngle = rng.nextDouble() * math.pi * 2;
      final hasBlob = rng.nextDouble() < 0.55;
      grid[row(best.dy) * cols + col(best.dx)].add(dots.length);
      dots.add(
        ObstacleDot(
          id: dots.length,
          center: best,
          radius: radius,
          opacity:
              config.minObstacleOpacity +
              rng.nextDouble() *
                  (config.maxObstacleOpacity - config.minObstacleOpacity),
          size: obstacleSizeFor(radius, config),
          blobOffset: hasBlob
              ? Offset(math.cos(blobAngle), math.sin(blobAngle)) *
                    radius *
                    (0.22 + rng.nextDouble() * 0.1)
              : Offset.zero,
          blobScale: hasBlob ? 0.55 + rng.nextDouble() * 0.13 : 0,
        ),
      );
    }

    // Ids follow list order (biggest first) so the spatial grid lines up.
    return ObstacleField(dots: dots, bounds: field, seed: seed);
  }

  double _tierRadius(math.Random rng) {
    final roll = rng.nextDouble();
    final base = roll < config.smallDotShare
        ? config.smallDotRadius
        : roll < config.smallDotShare + config.mediumDotShare
        ? config.mediumDotRadius
        : config.largeDotRadius;
    return base + (rng.nextDouble() * 2 - 1) * config.dotRadiusJitter;
  }

  /// Edge-to-edge distance from a dot at [p] to its nearest neighbour
  /// (capped when nothing is nearby).
  double _gapAt(
    Offset p,
    double radius,
    List<ObstacleDot> dots,
    List<List<int>> grid,
    int cols,
    int Function(double) col,
    int Function(double) row,
  ) {
    const reach = 80.0;
    var nearest = reach;
    final c0 = col(p.dx - reach), c1 = col(p.dx + reach);
    final r0 = row(p.dy - reach), r1 = row(p.dy + reach);
    for (var r = r0; r <= r1; r++) {
      for (var c = c0; c <= c1; c++) {
        for (final i in grid[r * cols + c]) {
          final other = dots[i];
          final gap = (other.center - p).distance - radius - other.radius;
          if (gap < nearest) nearest = gap;
        }
      }
    }
    return nearest;
  }
}

/// Probability of keeping a dot near the field border: a thin, torn fringe
/// at the top and bottom, almost none at the sides.
class _Edge {
  _Edge(this.field, this.seed);

  final Rect field;
  final double seed;

  double at(Offset p) {
    final distX = math.min(p.dx - field.left, field.right - p.dx);
    final distY = math.min(p.dy - field.top, field.bottom - p.dy);
    final wobbleY =
        14 +
        9 * math.sin(p.dx * 0.031 + seed) +
        6 * math.sin(p.dx * 0.011 + seed * 1.7);
    final wobbleX = 5 + 3 * math.sin(p.dy * 0.043 + seed);
    // Clamp: the summed waves must never shrink the margin to zero, or a
    // whole column would be rejected and leave an empty stripe.
    return _smooth(distY / wobbleY.clamp(6.0, 40.0)) * _smooth(distX / wobbleX);
  }

  static double _smooth(double x) {
    final t = x.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }
}
