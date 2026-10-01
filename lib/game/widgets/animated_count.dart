import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// A number that rolls toward its new value and flashes when it drops.
class AnimatedCount extends StatefulWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    required this.style,
    this.dropColor = AppColors.penalty,
    this.gainColor,
  });

  final int value;
  final TextStyle style;
  final Color dropColor;
  final Color? gainColor;

  @override
  State<AnimatedCount> createState() => _AnimatedCountState();
}

class _AnimatedCountState extends State<AnimatedCount>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late int _from = widget.value;
  Color? _flashColor;

  @override
  void didUpdateWidget(AnimatedCount old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _from = old.value;
      // Small increments from steady movement shouldn't flash; drops always do.
      if (widget.value < old.value) {
        _flashColor = widget.dropColor;
        _flash.forward(from: 0);
      } else if (widget.gainColor != null && widget.value - old.value > 50) {
        _flashColor = widget.gainColor;
        _flash.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(widget.value),
      tween: Tween(begin: _from.toDouble(), end: widget.value.toDouble()),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => AnimatedBuilder(
        animation: _flash,
        builder: (context, _) {
          final t = _flash.isAnimating ? 1 - _flash.value : 0.0;
          return Transform.scale(
            scale: 1 + 0.12 * t,
            alignment: Alignment.centerLeft,
            child: Text(
              formatThousands(v.round()),
              style: widget.style.copyWith(
                color: Color.lerp(widget.style.color, _flashColor, t),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 1240 → "1,240".
String formatThousands(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return negative ? '-$buffer' : buffer.toString();
}
