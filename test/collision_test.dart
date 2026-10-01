import 'dart:ui';

import 'package:dotline_duel/game/controllers/collision_controller.dart';
import 'package:dotline_duel/game/models/game_config.dart';
import 'package:dotline_duel/game/models/obstacle_dot.dart';
import 'package:dotline_duel/game/utils/collision_utils.dart';
import 'package:flutter_test/flutter_test.dart';

ObstacleField fieldWith(List<ObstacleDot> dots) => ObstacleField(
  dots: dots,
  bounds: const Rect.fromLTWH(0, 0, 1000, 1600),
  seed: 0,
);

ObstacleDot dot(
  int id,
  Offset c,
  double r, [
  ObstacleSize s = ObstacleSize.medium,
]) => ObstacleDot(id: id, center: c, radius: r, opacity: 1, size: s);

void main() {
  const config = GameConfig(); // playerRadius 12, tolerance 2, cooldown 300ms

  group('collision maths', () {
    test('distance to segment uses the closest point', () {
      expect(
        distanceToSegmentSquared(
          const Offset(5, 5),
          Offset.zero,
          const Offset(10, 0),
        ),
        closeTo(25, 1e-9),
      );
      // Beyond the end: distance to the end point.
      expect(
        distanceToSegmentSquared(
          const Offset(13, 4),
          Offset.zero,
          const Offset(10, 0),
        ),
        closeTo(25, 1e-9),
      );
    });

    test('a fast pen cannot tunnel through a small dot', () {
      // Moves 400 units in one step straight across a 4-unit dot.
      expect(
        sweptCircleHits(
          from: const Offset(0, 100),
          to: const Offset(400, 100),
          penRadius: 12,
          center: const Offset(200, 100),
          radius: 4,
        ),
        isTrue,
      );
    });

    test('tolerance forgives a grazing touch', () {
      bool hits(double tolerance) => sweptCircleHits(
        from: const Offset(0, 0),
        to: const Offset(0, 0),
        penRadius: 12,
        center: const Offset(21, 0),
        radius: 10,
        tolerance: tolerance,
      );
      expect(hits(0), isTrue); // 21 < 22
      expect(hits(2), isFalse); // 21 > 20
    });
  });

  group('CollisionController', () {
    final target = dot(0, const Offset(500, 500), 8);
    final field = fieldWith([target]);

    test('continuous contact is penalised only once', () {
      final c = CollisionController(config);
      var penalties = 0;
      var t = 0.0;
      // 0.5 s of sitting on the same dot at 60 fps.
      for (var i = 0; i < 30; i++) {
        penalties += c
            .step(field, const Offset(500, 500), const Offset(500, 501), t)
            .length;
        t += 1 / 60;
      }
      expect(penalties, 1);
      expect(c.isTouching, isTrue);
    });

    test('touching the same dot repeatedly within the cooldown is free', () {
      final c = CollisionController(config);
      const on = Offset(500, 500);
      const off = Offset(500, 600);
      expect(c.step(field, on, on, 0.00).length, 1); // first touch
      expect(c.step(field, off, off, 0.05).length, 0); // left the dot
      expect(c.step(field, on, on, 0.10).length, 0); // back, still cooling down
      expect(c.step(field, off, off, 0.15).length, 0);
      expect(c.step(field, on, on, 0.40).length, 1); // cooldown expired
    });

    test('different dots are penalised independently', () {
      final c = CollisionController(config);
      final cluster = fieldWith([
        dot(0, const Offset(500, 500), 5),
        dot(1, const Offset(500, 540), 5),
        dot(2, const Offset(500, 580), 5),
      ]);
      final hits = c.step(
        cluster,
        const Offset(500, 450),
        const Offset(500, 650),
        0,
      );
      expect(hits.map((d) => d.id), unorderedEquals([0, 1, 2]));
    });

    test('missing a dot costs nothing', () {
      final c = CollisionController(config);
      expect(
        c.step(field, const Offset(400, 400), const Offset(400, 700), 0),
        isEmpty,
      );
    });

    test('reset clears cooldowns for a new run', () {
      final c = CollisionController(config);
      expect(
        c.step(field, const Offset(500, 500), const Offset(500, 500), 0).length,
        1,
      );
      c.reset();
      expect(
        c
            .step(field, const Offset(500, 500), const Offset(500, 500), 0.01)
            .length,
        1,
      );
    });
  });
}
