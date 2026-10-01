import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../../app/theme.dart';

/// Warm paper background with faint grain and a soft vignette. Static, so it
/// is painted once and cached by its RepaintBoundary.
class PaperPainter extends CustomPainter {
  const PaperPainter({this.seed = 7});

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = AppColors.paper);

    // Grain: tiny, very faint fibres and specks.
    final rng = math.Random(seed);
    final speck = Paint();
    final count = (size.width * size.height / 900).clamp(150, 900).round();
    for (var i = 0; i < count; i++) {
      final p = Offset(
        rng.nextDouble() * size.width,
        rng.nextDouble() * size.height,
      );
      speck.color = AppColors.ink.withValues(
        alpha: 0.025 + rng.nextDouble() * 0.035,
      );
      canvas.drawCircle(p, 0.4 + rng.nextDouble() * 0.7, speck);
    }

    // Vignette towards the edges, like light falling on a sheet of paper.
    // RadialGradient's radius is relative to the shortest side, so scale it
    // to reach the corners on tall screens too.
    final shortest = math.min(size.width, size.height);
    final halfDiagonal =
        math.sqrt(size.width * size.width + size.height * size.height) / 2;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: halfDiagonal / shortest,
          colors: [
            const Color(0x00000000),
            AppColors.paperEdge.withValues(alpha: 0.4),
          ],
          stops: const [0.6, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(PaperPainter old) => old.seed != seed;
}
