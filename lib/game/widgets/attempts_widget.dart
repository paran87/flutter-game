import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// A row of hearts; a heart that is lost pops and fades to an outline.
class AttemptsWidget extends StatelessWidget {
  const AttemptsWidget({
    super.key,
    required this.remaining,
    required this.max,
    required this.color,
    this.size = 14,
  });

  final int remaining;
  final int max;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$remaining of $max attempts left',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < max; i++)
            Padding(
              padding: EdgeInsets.only(right: i == max - 1 ? 0 : 2),
              child: _Heart(alive: i < remaining, color: color, size: size),
            ),
        ],
      ),
    );
  }
}

class _Heart extends StatelessWidget {
  const _Heart({required this.alive, required this.color, required this.size});

  final bool alive;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: alive ? 1 : 0),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOut,
      builder: (context, t, _) {
        // A lost heart briefly swells as t falls 1 → 0, then fades out.
        final scale = 1 + 0.6 * math.sin(t * math.pi);
        return Transform.scale(
          scale: scale,
          child: Icon(
            t > 0.5 ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: size,
            color: Color.lerp(
              AppColors.inkFaint.withValues(alpha: 0.5),
              color,
              t,
            ),
          ),
        );
      },
    );
  }
}
