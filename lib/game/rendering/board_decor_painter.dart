import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../models/game_config.dart';
import 'board_transform.dart';

/// Static board furniture: hand-drawn goal lines and start pads.
class BoardDecorPainter extends CustomPainter {
  BoardDecorPainter({
    required this.config,
    required this.transform,
    required this.topColor,
    required this.bottomColor,
  });

  final GameConfig config;
  final BoardTransform transform;
  final Color topColor;
  final Color bottomColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(transform.origin.dx, transform.origin.dy);
    canvas.scale(transform.scale);

    // Goal lines: where each player must reach. The line in front of the top
    // player's balloons is the bottom player's finish, and vice versa.
    _goalLine(canvas, config.bottomGoalY, bottomColor, seed: 3);
    _goalLine(canvas, config.topGoalY, topColor, seed: 11);

    _startPad(canvas, config.bottomStart, bottomColor);
    _startPad(canvas, config.topStart, topColor);
    canvas.restore();
  }

  void _goalLine(Canvas canvas, double y, Color color, {required int seed}) {
    final rng = math.Random(seed);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    // Short wobbly dashes, as if ruled freehand.
    const dash = 26.0;
    const gap = 16.0;
    for (var x = 60.0; x < config.worldWidth - 60; x += dash + gap) {
      final y0 = y + (rng.nextDouble() - 0.5) * 3;
      final y1 = y + (rng.nextDouble() - 0.5) * 3;
      canvas.drawLine(
        Offset(x, y0),
        Offset(math.min(x + dash, config.worldWidth - 60), y1),
        paint,
      );
    }
  }

  void _startPad(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(
      center,
      30,
      Paint()..color = color.withValues(alpha: 0.08),
    );
    canvas.drawCircle(
      center,
      30,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(BoardDecorPainter old) =>
      old.transform != transform || old.config != config;
}
