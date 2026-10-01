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

/// Generates an organic, seeded dot field.
///
/// Rather than a grid or uniform scatter, dots are rejection-sampled against
/// a density map built from:
///   * a handful of Gaussian *clusters* (dense patches),
///   * a few *voids* (natural gaps),
///   * 2–3 meandering *channels* from top to bottom — narrow risky
///     shortcuts and wider detours, so careful drawing is rewarded,
///   * low-frequency wave noise (unevenness everywhere),
///   * a ragged edge falloff (the field has no hard rectangular border).
/// Radii are skewed toward small dots so large blots stay special.
class ObstacleGenerator {
  ObstacleGenerator(this.config);

  final GameConfig config;

  ObstacleField generate(int seed) {
    final rng = math.Random(seed);
    final field = config.fieldRect;
    final density = _DensityMap.random(rng, field);
    final target = config.obstacleCount;

    final dots = <ObstacleDot>[];
    // Coarse grid for spacing checks while sampling.
    const cell = 32.0;
    final cols = (field.width / cell).ceil() + 1;
    final rows = (field.height / cell).ceil() + 1;
    final grid = List.generate(cols * rows, (_) => <int>[]);
    int col(double x) => ((x - field.left) / cell).floor().clamp(0, cols - 1);
    int row(double y) => ((y - field.top) / cell).floor().clamp(0, rows - 1);

    final maxAttempts = target * 40;
    for (
      var attempt = 0;
      attempt < maxAttempts && dots.length < target;
      attempt++
    ) {
      final p = Offset(
        field.left + rng.nextDouble() * field.width,
        field.top + rng.nextDouble() * field.height,
      );
      if (rng.nextDouble() > density.at(p)) continue;

      // Skewed toward small dots; dense patches grow slightly larger blots.
      final u = math.pow(rng.nextDouble(), 1.9).toDouble();
      final radius =
          config.minObstacleRadius +
          (config.maxObstacleRadius - config.minObstacleRadius) * u;

      if (!_hasRoom(p, radius, dots, grid, cols, col, row)) continue;

      final light = rng.nextDouble() < config.lightDotChance;
      final opacity = light
          ? config.minObstacleOpacity + rng.nextDouble() * 0.28
          : 0.72 + rng.nextDouble() * (config.maxObstacleOpacity - 0.72);

      final blobAngle = rng.nextDouble() * math.pi * 2;
      final hasBlob = rng.nextDouble() < 0.55;
      final dot = ObstacleDot(
        id: dots.length,
        center: p,
        radius: radius,
        opacity: opacity,
        size: obstacleSizeFor(radius, config),
        blobOffset: hasBlob
            ? Offset(math.cos(blobAngle), math.sin(blobAngle)) *
                  radius *
                  (0.22 + rng.nextDouble() * 0.1)
            : Offset.zero,
        blobScale: hasBlob ? 0.55 + rng.nextDouble() * 0.13 : 0,
      );
      grid[row(p.dy) * cols + col(p.dx)].add(dots.length);
      dots.add(dot);
    }

    return ObstacleField(dots: dots, bounds: field, seed: seed);
  }

  bool _hasRoom(
    Offset p,
    double radius,
    List<ObstacleDot> dots,
    List<List<int>> grid,
    int cols,
    int Function(double) col,
    int Function(double) row,
  ) {
    final reach = radius + config.maxObstacleRadius + config.minObstacleSpacing;
    final c0 = col(p.dx - reach), c1 = col(p.dx + reach);
    final r0 = row(p.dy - reach), r1 = row(p.dy + reach);
    for (var r = r0; r <= r1; r++) {
      for (var c = c0; c <= c1; c++) {
        for (final i in grid[r * cols + c]) {
          final other = dots[i];
          final minGap = radius + other.radius + config.minObstacleSpacing;
          if ((other.center - p).distanceSquared < minGap * minGap) {
            return false;
          }
        }
      }
    }
    return true;
  }
}

/// Probability (0..1) of keeping a sampled dot at a given position.
class _DensityMap {
  _DensityMap(
    this.field,
    this.clusters,
    this.voids,
    this.channels,
    this.waves,
    this.edgeSeed,
  );

  factory _DensityMap.random(math.Random rng, Rect field) {
    Offset randomPoint() => Offset(
      field.left + rng.nextDouble() * field.width,
      field.top + rng.nextDouble() * field.height,
    );
    final clusters = [
      for (var i = 0; i < 6 + rng.nextInt(4); i++)
        _Blob(
          randomPoint(),
          90 + rng.nextDouble() * 160,
          0.35 + rng.nextDouble() * 0.5,
        ),
    ];
    final voids = [
      for (var i = 0; i < 3 + rng.nextInt(3); i++)
        _Blob(
          randomPoint(),
          45 + rng.nextDouble() * 85,
          0.55 + rng.nextDouble() * 0.4,
        ),
    ];
    final channels = [
      for (var i = 0; i < 2 + rng.nextInt(2); i++) _Channel.random(rng, field),
    ];
    final waves = [
      for (var i = 0; i < 4; i++)
        _Wave(
          angle: rng.nextDouble() * math.pi,
          frequency: 0.006 + rng.nextDouble() * 0.012,
          phase: rng.nextDouble() * math.pi * 2,
        ),
    ];
    return _DensityMap(
      field,
      clusters,
      voids,
      channels,
      waves,
      rng.nextDouble() * 100,
    );
  }

  final Rect field;
  final List<_Blob> clusters;
  final List<_Blob> voids;
  final List<_Channel> channels;
  final List<_Wave> waves;
  final double edgeSeed;

  double at(Offset p) {
    var d = 0.32;
    for (final c in clusters) {
      d += c.weight * c.falloff(p);
    }
    for (final v in voids) {
      d -= v.weight * v.falloff(p);
    }
    var noise = 0.0;
    for (final w in waves) {
      noise += w.at(p);
    }
    d += 0.12 * noise / waves.length;
    var open = 1.0;
    for (final c in channels) {
      open *= c.openness(p);
    }
    return d.clamp(0.0, 1.0) * open * _edge(p);
  }

  /// Falloff toward the field border: torn and ragged at the top and bottom
  /// (like the reference sketch), but only a thin fringe on the left and
  /// right so the sides never become an empty, risk-free lane.
  double _edge(Offset p) {
    final distX = math.min(p.dx - field.left, field.right - p.dx);
    final distY = math.min(p.dy - field.top, field.bottom - p.dy);
    final wobbleY =
        22 +
        18 * math.sin(p.dx * 0.031 + edgeSeed) +
        14 * math.sin(p.dx * 0.011 + edgeSeed * 1.7);
    final wobbleX = 6 + 4 * math.sin(p.dy * 0.043 + edgeSeed);
    return _smooth(distY / wobbleY.clamp(8, 60)) * _smooth(distX / wobbleX);
  }

  static double _smooth(double x) {
    final t = x.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }
}

/// A meandering, mostly-empty corridor running from the top of the field to
/// the bottom. Its x position wanders like a random walk.
class _Channel {
  _Channel(this.top, this.step, this.xs, this.halfWidth, this.depth);

  factory _Channel.random(math.Random rng, Rect field) {
    const step = 40.0;
    final count = (field.height / step).ceil() + 1;
    var x = field.left + 90 + rng.nextDouble() * (field.width - 180);
    var drift = 0.0;
    final xs = <double>[];
    for (var i = 0; i < count; i++) {
      xs.add(x);
      // Smoothed random walk: drift changes gradually, so the channel curves.
      drift = drift * 0.7 + (rng.nextDouble() - 0.5) * 34;
      x = (x + drift).clamp(field.left + 60, field.right - 60);
    }
    return _Channel(
      field.top,
      step,
      xs,
      18 + rng.nextDouble() * 22,
      0.85 + rng.nextDouble() * 0.12,
    );
  }

  final double top;
  final double step;
  final List<double> xs;

  /// Gaussian half-width of the corridor (world units).
  final double halfWidth;

  /// How empty the corridor centre is (1 = no dots at all).
  final double depth;

  /// 1 away from the channel, approaching (1 - depth) at its centre.
  double openness(Offset p) {
    final t = ((p.dy - top) / step).clamp(0.0, xs.length - 1.001);
    final i = t.floor();
    final x = xs[i] + (xs[i + 1] - xs[i]) * (t - i);
    final dx = p.dx - x;
    return 1 - depth * math.exp(-dx * dx / (2 * halfWidth * halfWidth));
  }
}

class _Blob {
  _Blob(this.center, this.sigma, this.weight);

  final Offset center;
  final double sigma;
  final double weight;

  double falloff(Offset p) {
    final d2 = (p - center).distanceSquared;
    return math.exp(-d2 / (2 * sigma * sigma));
  }
}

class _Wave {
  _Wave({required this.angle, required this.frequency, required this.phase});

  final double angle;
  final double frequency;
  final double phase;

  double at(Offset p) {
    final projected = p.dx * math.cos(angle) + p.dy * math.sin(angle);
    return math.sin(projected * frequency + phase);
  }
}
