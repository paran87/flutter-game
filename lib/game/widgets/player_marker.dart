import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Draws a player's pen marker. Used by the board painter every frame, and
/// wrapped by [PlayerMarker] for static use (tutorial, HUD).
abstract final class PlayerMarkerPainter {
  static final Map<String, TextPainter> _labels = {};

  /// [radius] is in canvas units. [pulse] (0..1) adds a soft halo, [shake]
  /// (0..1) jitters the marker after a collision, [dim] greys it out.
  static void paint(
    Canvas canvas,
    Offset center,
    double radius,
    Color color, {
    String? label,
    double pulse = 0,
    double shake = 0,
    bool dim = false,
    double opacity = 1,
  }) {
    if (opacity <= 0) return;
    var c = center;
    if (shake > 0) {
      c += Offset(
        math.sin(shake * 55) * radius * 0.35 * shake,
        math.cos(shake * 41) * radius * 0.2 * shake,
      );
    }
    final base = dim ? AppColors.inkFaint : color;

    // Always-on soft halo so the small pen tip stays easy to find.
    canvas.drawCircle(
      c,
      radius * 2.3,
      Paint()..color = base.withValues(alpha: 0.10 * opacity),
    );
    canvas.drawCircle(
      c,
      radius * 2.3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = base.withValues(alpha: 0.35 * opacity),
    );

    if (pulse > 0) {
      canvas.drawCircle(
        c,
        radius * (2.3 + pulse * 1.4),
        Paint()..color = base.withValues(alpha: 0.18 * (1 - pulse) * opacity),
      );
    }
    // Shadow.
    canvas.drawCircle(
      c + Offset(0, radius * 0.25),
      radius * 1.05,
      Paint()
        ..color = AppColors.ink.withValues(alpha: 0.18 * opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.35),
    );
    // Paper ring.
    canvas.drawCircle(
      c,
      radius * 1.18,
      Paint()..color = AppColors.card.withValues(alpha: opacity),
    );
    // Body.
    canvas.drawCircle(
      c,
      radius,
      Paint()..color = base.withValues(alpha: opacity),
    );
    // Ink outline.
    canvas.drawCircle(
      c,
      radius * 1.18,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, radius * 0.16)
        ..color = AppColors.ink.withValues(alpha: 0.8 * opacity),
    );
    // Pen tip highlight.
    canvas.drawCircle(
      c - Offset(radius * 0.28, radius * 0.28),
      radius * 0.28,
      Paint()..color = Colors.white.withValues(alpha: 0.55 * opacity),
    );

    if (label != null && opacity > 0.3) {
      final tp = _labelPainter(label, base);
      final chipW = tp.width + 10;
      final chipH = tp.height + 4;
      final chipRect = Rect.fromCenter(
        // Beside the marker so it never hides the path ahead or behind.
        center: c + Offset(radius * 2.3 + chipW / 2 + 4, 0),
        width: chipW,
        height: chipH,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(chipRect, Radius.circular(chipH / 2)),
        Paint()..color = base.withValues(alpha: 0.92 * opacity),
      );
      tp.paint(canvas, chipRect.center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  static TextPainter _labelPainter(String label, Color color) {
    final key = '$label|${color.toARGB32()}';
    return _labels.putIfAbsent(key, () {
      return TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }
}

/// A standalone marker widget for menus and the tutorial.
class PlayerMarker extends StatelessWidget {
  const PlayerMarker({
    super.key,
    required this.color,
    this.size = 22,
    this.label,
  });

  final Color color;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size * 1.6),
      painter: _MarkerWidgetPainter(color, size / 2, label),
    );
  }
}

class _MarkerWidgetPainter extends CustomPainter {
  _MarkerWidgetPainter(this.color, this.radius, this.label);

  final Color color;
  final double radius;
  final String? label;

  @override
  void paint(Canvas canvas, Size size) {
    PlayerMarkerPainter.paint(
      canvas,
      size.center(Offset.zero),
      radius,
      color,
      label: label,
    );
  }

  @override
  bool shouldRepaint(_MarkerWidgetPainter old) =>
      old.color != color || old.radius != radius || old.label != label;
}
