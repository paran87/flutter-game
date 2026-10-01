import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Ink-splash confetti for victories (and a gentle drift for draws).
class Celebration extends StatefulWidget {
  const Celebration({super.key, required this.colors, this.count = 70});

  final List<Color> colors;
  final int count;

  @override
  State<Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<Celebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..forward();

  late final List<_Particle> _particles = () {
    final rng = math.Random(7);
    return List.generate(widget.count, (i) {
      return _Particle(
        x: rng.nextDouble(),
        delay: rng.nextDouble() * 0.35,
        speed: 0.55 + rng.nextDouble() * 0.6,
        drift: (rng.nextDouble() - 0.5) * 0.25,
        size: 3 + rng.nextDouble() * 6,
        spin: (rng.nextDouble() - 0.5) * 10,
        color: widget.colors[i % widget.colors.length],
        stroke: rng.nextDouble() < 0.35,
      );
    });
  }();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _CelebrationPainter(_c, _particles),
        ),
      ),
    );
  }
}

class _Particle {
  _Particle({
    required this.x,
    required this.delay,
    required this.speed,
    required this.drift,
    required this.size,
    required this.spin,
    required this.color,
    required this.stroke,
  });

  final double x, delay, speed, drift, size, spin;
  final Color color;
  final bool stroke;
}

class _CelebrationPainter extends CustomPainter {
  _CelebrationPainter(this.animation, this.particles)
    : super(repaint: animation);

  final Animation<double> animation;
  final List<_Particle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    for (final p in particles) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y =
          -20 + (size.height * 0.9) * local * p.speed + 120 * local * local;
      final x =
          size.width * (p.x + p.drift * local) +
          math.sin(local * 8 + p.x * 20) * 10;
      final fade = local > 0.75 ? 1 - (local - 0.75) / 0.25 : 1.0;
      final paint = Paint()..color = p.color.withValues(alpha: 0.85 * fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * local);
      if (p.stroke) {
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: p.size),
          0,
          2.2,
          false,
          paint,
        );
      } else {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size * 1.4,
            height: p.size,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CelebrationPainter old) => false;
}
