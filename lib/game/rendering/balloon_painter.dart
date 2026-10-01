import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';

import '../../app/theme.dart';

/// Draws an original hand-inked balloon, including its pop sequence.
///
/// [popProgress] runs 0 → 1 over the pop animation:
///   0.00–0.40  swell + growing shake
///   0.40–0.52  anticipation (held breath, slight squash)
///   0.52–1.00  burst: shards, ink specks and a shock ring
class BalloonPainter extends CustomPainter {
  BalloonPainter({
    required this.color,
    this.popProgress = 0,
    this.destroyed = false,
    this.seed = 0,
  });

  final Color color;
  final double popProgress;
  final bool destroyed;
  final int seed;

  static const _burstAt = 0.52;

  @override
  void paint(Canvas canvas, Size size) {
    if (destroyed) {
      _paintRemnant(canvas, size);
      return;
    }
    if (popProgress >= _burstAt) {
      _paintBurst(canvas, size, (popProgress - _burstAt) / (1 - _burstAt));
      return;
    }

    var scale = 1.0;
    var shake = 0.0;
    var squash = 1.0;
    if (popProgress > 0) {
      if (popProgress < 0.4) {
        final t = popProgress / 0.4;
        scale = 1 + 0.2 * Curves.easeOut.transform(t);
        shake = math.sin(popProgress * 90) * 2.4 * t;
      } else {
        scale = 1.2;
        squash = 0.94;
      }
    }

    final bodyCenter = Offset(size.width / 2, size.height * 0.36);
    canvas.save();
    canvas.translate(bodyCenter.dx + shake, bodyCenter.dy);
    canvas.scale(scale / squash, scale * squash);
    canvas.translate(-bodyCenter.dx, -bodyCenter.dy);
    paintBalloon(canvas, size, color);
    canvas.restore();
  }

  /// The intact balloon, reused by HUD icons.
  static void paintBalloon(Canvas canvas, Size size, Color color) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final top = h * 0.03;
    final bodyH = h * 0.64;
    final bodyW = w * 0.86;
    final bottom = top + bodyH;

    // String: a loose ballpoint squiggle.
    final string = Path()
      ..moveTo(cx, bottom + h * 0.04)
      ..quadraticBezierTo(
        cx - w * 0.12,
        bottom + h * 0.13,
        cx,
        bottom + h * 0.2,
      )
      ..quadraticBezierTo(
        cx + w * 0.12,
        bottom + h * 0.27,
        cx - w * 0.02,
        h * 0.99,
      );
    canvas.drawPath(
      string,
      Paint()
        ..color = AppColors.inkSoft.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, w * 0.025)
        ..strokeCap = StrokeCap.round,
    );

    final body = Path()
      ..moveTo(cx, top)
      ..cubicTo(
        cx + bodyW * 0.64,
        top,
        cx + bodyW * 0.56,
        top + bodyH * 0.8,
        cx,
        bottom,
      )
      ..cubicTo(
        cx - bodyW * 0.56,
        top + bodyH * 0.8,
        cx - bodyW * 0.64,
        top,
        cx,
        top,
      )
      ..close();

    // Soft drop shadow on the paper.
    canvas.drawPath(
      body.shift(Offset(w * 0.04, h * 0.03)),
      Paint()
        ..color = AppColors.ink.withValues(alpha: 0.10)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.05),
    );

    final bounds = body.getBounds();
    canvas.drawPath(
      body,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 0.95,
          colors: [
            Color.lerp(color, const Color(0xFFFFFFFF), 0.35)!,
            color,
            Color.lerp(color, const Color(0xFF000000), 0.28)!,
          ],
          stops: const [0, 0.55, 1],
        ).createShader(bounds),
    );

    // Ink outline, slightly heavier on the shadow side.
    canvas.drawPath(
      body,
      Paint()
        ..color = AppColors.ink.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, w * 0.035)
        ..strokeJoin = StrokeJoin.round,
    );

    // Highlight.
    canvas.save();
    canvas.translate(cx - bodyW * 0.2, top + bodyH * 0.26);
    canvas.rotate(-0.5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: bodyW * 0.16,
        height: bodyH * 0.24,
      ),
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.6),
    );
    canvas.restore();

    // Knot.
    final knot = Path()
      ..moveTo(cx, bottom - h * 0.005)
      ..lineTo(cx - w * 0.07, bottom + h * 0.05)
      ..lineTo(cx + w * 0.07, bottom + h * 0.05)
      ..close();
    canvas.drawPath(
      knot,
      Paint()..color = Color.lerp(color, const Color(0xFF000000), 0.3)!,
    );
  }

  void _paintBurst(Canvas canvas, Size size, double t) {
    final center = Offset(size.width / 2, size.height * 0.36);
    final rng = math.Random(seed);
    final reach = size.width * 0.95;
    final eased = Curves.easeOutCubic.transform(t);
    final fade = 1 - Curves.easeIn.transform(t);

    // Shock ring.
    canvas.drawCircle(
      center,
      size.width * (0.35 + 0.7 * eased),
      Paint()
        ..color = color.withValues(alpha: 0.5 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.05 * fade + 0.5,
    );

    // Rubber shards.
    final shardPaint = Paint()..color = color.withValues(alpha: fade);
    for (var i = 0; i < 11; i++) {
      final angle = i / 11 * math.pi * 2 + rng.nextDouble() * 0.5;
      final dist = reach * (0.45 + rng.nextDouble() * 0.55) * eased;
      final p = center + Offset(math.cos(angle), math.sin(angle)) * dist;
      final s = size.width * (0.06 + rng.nextDouble() * 0.07) * (1 - 0.4 * t);
      canvas.save();
      canvas.translate(p.dx, p.dy + 9 * t * t);
      canvas.rotate(angle + t * (rng.nextBool() ? 4 : -4));
      final shard = Path()
        ..moveTo(-s, -s * 0.4)
        ..lineTo(s * 0.9, -s * 0.6)
        ..lineTo(s * 0.4, s * 0.7)
        ..close();
      canvas.drawPath(shard, shardPaint);
      canvas.restore();
    }

    // Ink specks.
    final speckPaint = Paint()
      ..color = AppColors.ink.withValues(alpha: 0.7 * fade);
    for (var i = 0; i < 9; i++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final dist = reach * (0.3 + rng.nextDouble() * 0.6) * eased;
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * dist,
        size.width * 0.018 + rng.nextDouble() * size.width * 0.02,
        speckPaint,
      );
    }

    // The string drops away.
    if (t < 0.7) {
      final drop = size.height * 0.35 * t * t;
      final a = 1 - t / 0.7;
      canvas.drawLine(
        Offset(size.width / 2, size.height * 0.72 + drop),
        Offset(size.width / 2 - size.width * 0.03, size.height * 0.98 + drop),
        Paint()
          ..color = AppColors.inkSoft.withValues(alpha: 0.7 * a)
          ..strokeWidth = math.max(0.8, size.width * 0.025),
      );
    }
  }

  /// What remains after a pop: a dashed ghost outline and a limp knot.
  void _paintRemnant(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.36);
    final radius = size.width * 0.36;
    final dashPaint = Paint()
      ..color = AppColors.inkFaint.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, size.width * 0.025)
      ..strokeCap = StrokeCap.round;
    const dashes = 14;
    for (var i = 0; i < dashes; i++) {
      final start = i / dashes * math.pi * 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        math.pi / dashes,
        false,
        dashPaint,
      );
    }
    final knotY = size.height * 0.78;
    final knot = Path()
      ..moveTo(size.width / 2 - size.width * 0.08, knotY - size.height * 0.03)
      ..lineTo(size.width / 2 + size.width * 0.06, knotY - size.height * 0.04)
      ..lineTo(size.width / 2, knotY + size.height * 0.02)
      ..close();
    canvas.drawPath(knot, Paint()..color = color.withValues(alpha: 0.55));
    canvas.drawLine(
      Offset(size.width / 2, knotY + size.height * 0.02),
      Offset(size.width / 2 + size.width * 0.05, size.height * 0.99),
      Paint()
        ..color = AppColors.inkFaint.withValues(alpha: 0.6)
        ..strokeWidth = math.max(0.8, size.width * 0.02),
    );
  }

  @override
  bool shouldRepaint(BalloonPainter old) =>
      old.color != color ||
      old.popProgress != popProgress ||
      old.destroyed != destroyed ||
      old.seed != seed;
}
