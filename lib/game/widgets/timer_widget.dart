import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Large countdown pill. Turns amber in the warning window and pulses red in
/// the final seconds.
class TimerWidget extends StatefulWidget {
  const TimerWidget({
    super.key,
    required this.seconds,
    required this.warningSeconds,
    required this.criticalSeconds,
    this.running = true,
    this.compact = false,
  });

  final int seconds;
  final int warningSeconds;
  final int criticalSeconds;

  /// False while the clock is paused between rounds (shown dimmed).
  final bool running;

  /// Smaller variant for narrow screens.
  final bool compact;

  @override
  State<TimerWidget> createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<TimerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  bool get _critical =>
      widget.seconds <= widget.criticalSeconds && widget.seconds > 0;
  bool get _warning => widget.seconds <= widget.warningSeconds;

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(TimerWidget old) {
    super.didUpdateWidget(old);
    _syncPulse();
    // Re-sync the pulse to each tick so the beat lands on the second change.
    if (_critical && old.seconds != widget.seconds && widget.running) {
      _pulse.forward(from: 0);
    }
  }

  void _syncPulse() {
    if (!_critical || !widget.running) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _critical
        ? AppColors.danger
        : _warning
        ? AppColors.warning
        : AppColors.ink;
    final minutes = widget.seconds ~/ 60;
    final secs = widget.seconds % 60;
    final label =
        '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Semantics(
      label: 'Time remaining $minutes minutes $secs seconds',
      liveRegion: _critical,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final beat = _pulse.isAnimating
              ? math.sin(_pulse.value * math.pi)
              : 0.0;
          return Transform.scale(scale: 1 + 0.12 * beat, child: child);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 9 : 14,
            vertical: widget.compact ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: _critical
                ? AppColors.danger.withValues(alpha: 0.1)
                : AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: color.withValues(alpha: 0.85), width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!widget.compact) ...[
                Icon(Icons.timer_outlined, size: 18, color: color),
                const SizedBox(width: 4),
              ],
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(
                  fontSize: widget.compact ? 19 : 24,
                  fontWeight: FontWeight.w900,
                  color: widget.running ? color : color.withValues(alpha: 0.55),
                  letterSpacing: 1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
