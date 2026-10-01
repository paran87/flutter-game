import 'dart:ui';

import 'package:dotline_duel/game/models/game_config.dart';
import 'package:dotline_duel/game/models/obstacle_dot.dart';
import 'package:dotline_duel/game/utils/obstacle_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const config = GameConfig();
  final generator = ObstacleGenerator(config);

  test('same seed reproduces the same layout', () {
    final a = generator.generate(42);
    final b = generator.generate(42);
    expect(a.dots.length, b.dots.length);
    for (var i = 0; i < a.dots.length; i++) {
      expect(a.dots[i].center, b.dots[i].center);
      expect(a.dots[i].radius, b.dots[i].radius);
    }
  });

  test('different seeds produce different layouts', () {
    final a = generator.generate(1);
    final b = generator.generate(2);
    expect(a.dots.first.center, isNot(b.dots.first.center));
  });

  test('generates hundreds of dots inside the field with min spacing', () {
    final field = generator.generate(7);
    expect(field.dots.length, greaterThan(config.obstacleCount * 0.8));
    for (final d in field.dots) {
      expect(config.fieldRect.contains(d.center), isTrue);
      expect(
        d.radius,
        inInclusiveRange(config.minObstacleRadius, config.maxObstacleRadius),
      );
      expect(
        d.opacity,
        inInclusiveRange(config.minObstacleOpacity, config.maxObstacleOpacity),
      );
    }
    for (var i = 0; i < field.dots.length; i++) {
      for (var j = i + 1; j < field.dots.length; j++) {
        final a = field.dots[i], b = field.dots[j];
        final gap = (a.center - b.center).distance - a.radius - b.radius;
        expect(gap, greaterThanOrEqualTo(config.minObstacleSpacing - 1e-9));
      }
    }
  });

  test('size tiers follow configured radius thresholds', () {
    expect(obstacleSizeFor(3, config), ObstacleSize.small);
    expect(
      obstacleSizeFor(config.mediumObstacleRadius, config),
      ObstacleSize.medium,
    );
    expect(
      obstacleSizeFor(config.largeObstacleRadius, config),
      ObstacleSize.large,
    );
    final field = generator.generate(9);
    final sizes = field.dots.map((d) => d.size).toSet();
    expect(sizes, containsAll(ObstacleSize.values));
  });

  test('density scales the dot count', () {
    final sparse = ObstacleGenerator(config.copyWith(obstacleDensity: 0.5))
        .generate(3);
    final dense = generator.generate(3);
    expect(sparse.dots.length, lessThan(dense.dots.length));
  });

  test('spatial grid returns every dot near a point', () {
    final field = generator.generate(11);
    const probe = Offset(500, 800);
    final area = Rect.fromCircle(center: probe, radius: 60);
    final candidates = field.candidatesIn(area);
    for (final d in field.dots) {
      if ((d.center - probe).distance < 60 - d.radius) {
        expect(candidates, contains(d.id));
      }
    }
  });

  test('the field is evenly filled: no empty stripes or patches', () {
    for (var seed = 1; seed <= 12; seed++) {
      final field = generator.generate(seed);
      final rect = config.fieldRect;
      // Every 40-unit vertical stripe across the field holds plenty of dots.
      for (var x = rect.left; x < rect.right - 40; x += 40) {
        final inStripe = field.dots
            .where((d) => d.center.dx >= x && d.center.dx < x + 40)
            .length;
        expect(inStripe, greaterThan(20), reason: 'seed $seed stripe at x=$x');
      }
      // And no open hole inside the field wider than about a pen.
      for (var x = rect.left + 30; x < rect.right - 30; x += 12) {
        for (var y = rect.top + 40; y < rect.bottom - 40; y += 12) {
          final probe = Offset(x, y);
          final nearest = field.dots
              .map((d) => (d.center - probe).distance - d.radius)
              .reduce((a, b) => a < b ? a : b);
          expect(nearest, lessThan(32), reason: 'seed $seed hole at $probe');
        }
      }
    }
  });

  test('every dot is dark ink and one of three clear sizes', () {
    final field = generator.generate(5);
    for (final d in field.dots) {
      expect(d.opacity, greaterThanOrEqualTo(config.minObstacleOpacity));
      final tierRadius = switch (d.size) {
        ObstacleSize.small => config.smallDotRadius,
        ObstacleSize.medium => config.mediumDotRadius,
        ObstacleSize.large => config.largeDotRadius,
      };
      expect(
        (d.radius - tierRadius).abs(),
        lessThanOrEqualTo(config.dotRadiusJitter + 1e-9),
      );
    }
    final share =
        field.dots.where((d) => d.size == ObstacleSize.large).length /
        field.dots.length;
    expect(share, inInclusiveRange(0.12, 0.3));
  });
}
