import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../models/game_config.dart';
import '../models/obstacle_dot.dart';
import '../rendering/obstacle_painter.dart';
import '../utils/obstacle_generator.dart';

/// Living sketch behind the home menu: a faint dot field with a red and a
/// blue ballpoint line endlessly drawing themselves through it.
class HomeBackdrop extends StatefulWidget {
  const HomeBackdrop({super.key});

  @override
  State<HomeBackdrop> createState() => _HomeBackdropState();
}

class _HomeBackdropState extends State<HomeBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat();

  static const _config = GameConfig(obstacleDensity: 0.75);
  late final ObstacleField _field = ObstacleGenerator(_config).generate(2024);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(painter: _FieldPainter(_field, _config)),
          ),
          RepaintBoundary(child: CustomPaint(painter: _LinesPainter(_c))),
        ],
      ),
    );
  }
}

/// Scales the world so the field covers the screen (cropping is fine here).
Matrix4 _coverTransform(Size size, GameConfig config) {
  final field = config.fieldRect;
  final scale = math.max(size.width / field.width, size.height / field.height);
  final dx = (size.width - field.width * scale) / 2 - field.left * scale;
  final dy = (size.height - field.height * scale) / 2 - field.top * scale;
  return Matrix4.identity()
    ..translateByDouble(dx, dy, 0, 1)
    ..scaleByDouble(scale, scale, 1, 1);
}

class _FieldPainter extends CustomPainter {
  _FieldPainter(this.field, this.config);

  final ObstacleField field;
  final GameConfig config;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..color = const Color(0x2E000000),
    );
    canvas.transform(_coverTransform(size, config).storage);
    final bleed = Paint();
    final core = Paint();
    for (final dot in field.dots) {
      ObstaclePainter.paintDot(canvas, dot, bleed, core);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FieldPainter old) => false;
}

class _LinesPainter extends CustomPainter {
  _LinesPainter(this.t) : super(repaint: t);

  final Animation<double> t;

  Path _wander(Size size, double seed, bool down) {
    final path = Path();
    final rng = math.Random(seed.toInt());
    var x = size.width * (0.3 + rng.nextDouble() * 0.4);
    final startY = down ? -10.0 : size.height + 10;
    path.moveTo(x, startY);
    const steps = 9;
    for (var i = 1; i <= steps; i++) {
      final y = down ? size.height * i / steps : size.height * (1 - i / steps);
      final nx = (x + (rng.nextDouble() - 0.5) * size.width * 0.45).clamp(
        size.width * 0.12,
        size.width * 0.88,
      );
      final my = down
          ? y - size.height / steps / 2
          : y + size.height / steps / 2;
      path.quadraticBezierTo(x, my, (x + nx) / 2, y);
      x = nx;
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final blue = _wander(size, 5, false);
    final red = _wander(size, 17, true);
    _drawPartial(canvas, blue, t.value, AppColors.p1);
    _drawPartial(canvas, red, (t.value + 0.35) % 1, AppColors.p2);
  }

  void _drawPartial(Canvas canvas, Path path, double t, Color color) {
    // Draw in over 70% of the loop, hold, then fade out.
    final draw = (t / 0.7).clamp(0.0, 1.0);
    final fade = t < 0.85 ? 1.0 : 1 - (t - 0.85) / 0.15;
    final metric = path.computeMetrics().first;
    final part = metric.extractPath(
      0,
      metric.length * Curves.easeInOut.transform(draw),
    );
    canvas.drawPath(
      part,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.45 * fade),
    );
    canvas.drawPath(
      part,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.75 * fade),
    );
  }

  @override
  bool shouldRepaint(_LinesPainter old) => false;
}
