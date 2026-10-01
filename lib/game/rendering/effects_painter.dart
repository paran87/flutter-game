import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controllers/effects_controller.dart';
import '../models/game_effects.dart';
import 'board_transform.dart';

/// Draws transient effects. Text is drawn in screen space so it stays
/// readable regardless of board scale.
class EffectsPainter {
  final Map<String, TextPainter> _textCache = {};

  void paintWorldEffects(Canvas canvas, EffectsController effects) {
    for (final flash in effects.flashes) {
      _paintFlash(canvas, flash);
    }
    for (final burst in effects.bursts) {
      _paintBurst(canvas, burst);
    }
  }

  void paintTexts(
    Canvas canvas,
    EffectsController effects,
    BoardTransform transform,
  ) {
    for (final text in effects.texts) {
      _paintText(canvas, text, transform);
    }
  }

  void _paintFlash(Canvas canvas, DotFlash flash) {
    final t = flash.progress;
    final fade = 1 - Curves.easeIn.transform(t);
    final dot = flash.dot;
    // Tint the dot itself, then a ring that expands away from it.
    canvas.drawCircle(
      dot.center,
      dot.radius * 1.05,
      Paint()..color = flash.color.withValues(alpha: 0.75 * fade),
    );
    canvas.drawCircle(
      dot.center,
      dot.radius + 4 + 14 * Curves.easeOut.transform(t),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * fade + 0.5
        ..color = flash.color.withValues(alpha: 0.6 * fade),
    );
  }

  void _paintBurst(Canvas canvas, RingBurst burst) {
    final t = burst.progress;
    final eased = Curves.easeOutCubic.transform(t);
    final fade = 1 - t;
    canvas.drawCircle(
      burst.position,
      burst.maxRadius * eased,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10 * fade + 1
        ..color = burst.color.withValues(alpha: 0.55 * fade),
    );
    canvas.drawCircle(
      burst.position,
      burst.maxRadius * 0.6 * eased,
      Paint()..color = burst.color.withValues(alpha: 0.12 * fade),
    );
    // A few ink sparks on the rim.
    final spark = Paint()..color = burst.color.withValues(alpha: 0.8 * fade);
    for (var i = 0; i < 8; i++) {
      final a = i / 8 * math.pi * 2 + burst.position.dx;
      final r = burst.maxRadius * (0.7 + 0.45 * eased);
      canvas.drawCircle(
        burst.position + Offset(math.cos(a), math.sin(a)) * r,
        4 * fade + 1,
        spark,
      );
    }
  }

  void _paintText(Canvas canvas, FloatingText text, BoardTransform transform) {
    final t = text.progress;
    final painter = _painterFor(text.text, text.color);
    final rise = 46 * Curves.easeOut.transform(t);
    final opacity = t < 0.65 ? 1.0 : 1 - (t - 0.65) / 0.35;
    // Pop in: overshoot then settle.
    final scale = t < 0.18
        ? 0.6 + 0.55 * Curves.easeOutBack.transform(t / 0.18)
        : 1.0;
    final center = transform.toScreen(text.position) - Offset(0, 18 + rise);

    canvas.saveLayer(
      Rect.fromCenter(
        center: center,
        width: painter.width * 1.6 + 8,
        height: painter.height * 1.6 + 8,
      ),
      Paint()..color = Color.fromRGBO(0, 0, 0, opacity),
    );
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }

  TextPainter _painterFor(String text, Color color) {
    final key = '$text|${color.toARGB32()}';
    final cached = _textCache[key];
    if (cached != null) return cached;
    if (_textCache.length > 64) _textCache.clear();
    final style = TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.5,
      color: color,
      shadows: const [
        Shadow(color: Colors.white, blurRadius: 0, offset: Offset(1.2, 1.2)),
        Shadow(color: Colors.white, blurRadius: 0, offset: Offset(-1.2, -1.2)),
        Shadow(color: Colors.white, blurRadius: 0, offset: Offset(1.2, -1.2)),
        Shadow(color: Colors.white, blurRadius: 0, offset: Offset(-1.2, 1.2)),
      ],
    );
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    return _textCache[key] = painter;
  }
}
