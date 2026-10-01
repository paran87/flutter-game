import 'dart:math' as math;

/// Urgency of the match clock.
enum TimerLevel { normal, warning, critical, expired }

/// The match clock. Pure logic: it only moves when [tick] is called, and the
/// GameController only ticks it while players are racing.
class TimerController {
  TimerController({
    required Duration duration,
    required this.warningSeconds,
    required this.criticalSeconds,
  }) : _remaining = duration.inMicroseconds / 1e6;

  final int warningSeconds;
  final int criticalSeconds;
  double _remaining;

  double get remaining => _remaining;
  bool get isExpired => _remaining <= 0;

  /// Whole seconds to display (02:00 → 0:00), rounding up so "0:00" only
  /// appears once time has really run out.
  int get displaySeconds => math.max(0, _remaining.ceil());

  TimerLevel get level {
    if (isExpired) return TimerLevel.expired;
    if (displaySeconds <= criticalSeconds) return TimerLevel.critical;
    if (displaySeconds <= warningSeconds) return TimerLevel.warning;
    return TimerLevel.normal;
  }

  /// Advances the clock. Returns the new level if it changed this tick.
  TimerLevel? tick(double dt) {
    if (isExpired) return null;
    final before = level;
    _remaining = math.max(0, _remaining - dt);
    final after = level;
    return after == before ? null : after;
  }
}
