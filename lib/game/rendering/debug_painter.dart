import 'package:flutter/rendering.dart';

import '../controllers/game_controller.dart';

/// Debug geometry in world coordinates: planned paths, trace sample points,
/// collision radii and the dots each pen is currently touching.
class DebugPainter {
  void paint(Canvas canvas, GameController c) {
    final config = c.config;
    for (final p in c.players) {
      final color = p.identity.color;

      // Planned route (bot) as a dashed line.
      final path = c.agentFor(p).debugPath;
      final dash = Paint()
        ..color = color.withValues(alpha: 0.55)
        ..strokeWidth = 2;
      for (var i = 1; i < path.length; i += 2) {
        canvas.drawLine(path[i - 1], path[i], dash);
      }

      // Every stored trace point (what distance is measured from).
      final pointPaint = Paint()..color = color.withValues(alpha: 0.7);
      for (final pt in p.trace.points) {
        canvas.drawCircle(pt, 1.4, pointPaint);
      }

      // Collision radius of the pen.
      canvas.drawCircle(
        p.position,
        config.playerRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFF00A86B),
      );

      // Dots in contact right now.
      final touching = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = const Color(0xFFFF00AA);
      for (final id in c.collisionsFor(p).touching) {
        final dot = c.field.value.dots[id];
        canvas.drawCircle(dot.center, dot.radius + 3, touching);
      }
    }

    // Goal lines and field bounds.
    final guide = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF00A86B);
    canvas.drawRect(config.fieldRect, guide);
    canvas.drawLine(
      Offset(0, config.bottomGoalY),
      Offset(config.worldWidth, config.bottomGoalY),
      guide,
    );
    canvas.drawLine(
      Offset(0, config.topGoalY),
      Offset(config.worldWidth, config.topGoalY),
      guide,
    );
  }
}
