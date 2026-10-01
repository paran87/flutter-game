import 'dart:ui';

import 'obstacle_dot.dart';

/// Short-lived visual effects. Pure data; drawn by the board painter.
abstract class TimedEffect {
  TimedEffect(this.duration);

  final double duration;
  double age = 0;

  double get progress => (age / duration).clamp(0.0, 1.0);
  bool get isDone => age >= duration;
}

/// Rising "-10" style text in world space.
class FloatingText extends TimedEffect {
  FloatingText({
    required this.position,
    required this.value,
    required this.color,
    this.prefix = '',
    double duration = 0.9,
  }) : super(duration);

  Offset position;
  int value;
  final Color color;
  final String prefix;

  String get text => '$prefix$value';
}

/// A dot briefly glowing in the colour of the player who touched it.
class DotFlash extends TimedEffect {
  DotFlash({required this.dot, required this.color, double duration = 0.45})
    : super(duration);

  final ObstacleDot dot;
  final Color color;
}

/// Expanding ring burst (success, failure, pop).
class RingBurst extends TimedEffect {
  RingBurst({
    required this.position,
    required this.color,
    this.maxRadius = 90,
    double duration = 0.7,
  }) : super(duration);

  final Offset position;
  final Color color;
  final double maxRadius;
}
