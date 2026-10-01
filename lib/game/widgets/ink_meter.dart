import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Horizontal "pen barrel" that shows how much ink is left for this run.
class InkMeter extends StatelessWidget {
  const InkMeter({
    super.key,
    required this.percent,
    required this.color,
    this.width = 92,
    this.compact = false,
  });

  final int percent;
  final Color color;
  final double width;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final low = percent <= 25;
    final fill = low ? AppColors.danger : color;
    final barHeight = compact ? 6.0 : 10.0;
    final bar = SizedBox(
      width: width,
      height: barHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.paperShade,
          borderRadius: BorderRadius.circular(barHeight),
          border: Border.all(color: AppColors.ink.withValues(alpha: 0.18)),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 160),
            widthFactor: (percent / 100).clamp(0.0, 1.0),
            heightFactor: 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(barHeight),
              ),
            ),
          ),
        ),
      ),
    );
    if (compact) return Semantics(label: 'Ink $percent percent', child: bar);

    return Semantics(
      label: 'Ink $percent percent',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit_rounded, size: 16, color: fill),
          const SizedBox(width: 4),
          bar,
          const SizedBox(width: 6),
          SizedBox(
            width: 34,
            child: Text(
              '$percent%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: low ? AppColors.danger : AppColors.inkSoft,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
