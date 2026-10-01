import 'package:flutter/rendering.dart';

import '../../app/theme.dart';
import '../models/obstacle_dot.dart';
import 'board_transform.dart';

/// Paints the static ink-dot field. It only repaints when a new field is
/// generated or the board is resized, and sits behind a RepaintBoundary so
/// the hundreds of dots are rasterised once, not every frame.
class ObstaclePainter extends CustomPainter {
  ObstaclePainter({required this.field, required this.transform});

  final ObstacleField field;
  final BoardTransform transform;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(transform.origin.dx, transform.origin.dy);
    canvas.scale(transform.scale);

    final bleed = Paint();
    final core = Paint();
    for (final dot in field.dots) {
      paintDot(canvas, dot, bleed, core);
    }
    canvas.restore();
  }

  /// Draws one dot as an ink blot: a faint bleed ring, the solid core and an
  /// optional satellite blob that breaks the perfect circle. Everything stays
  /// within [ObstacleDot.radius] so what you see is what you collide with.
  static void paintDot(
    Canvas canvas,
    ObstacleDot dot,
    Paint bleed,
    Paint core,
  ) {
    // Lighter dots are greyer, not just more transparent — like a pen that
    // barely touched the paper.
    final light = dot.opacity < 0.5;
    final color = light ? AppColors.inkSoft : AppColors.ink;

    bleed.color = color.withValues(alpha: dot.opacity * 0.16);
    canvas.drawCircle(dot.center, dot.radius * 1.08, bleed);

    core.color = color.withValues(alpha: dot.opacity);
    if (dot.blobScale > 0) {
      final path = Path()
        ..addOval(
          Rect.fromCircle(
            center: dot.center - dot.blobOffset * 0.4,
            radius: dot.radius * 0.88,
          ),
        )
        ..addOval(
          Rect.fromCircle(
            center: dot.center + dot.blobOffset,
            radius: dot.radius * dot.blobScale,
          ),
        );
      // nonZero fill so the overlap is not double-darkened.
      canvas.drawPath(path, core);
    } else {
      canvas.drawCircle(dot.center, dot.radius * 0.95, core);
    }
  }

  @override
  bool shouldRepaint(ObstaclePainter old) =>
      !identical(old.field, field) || old.transform != transform;
}
