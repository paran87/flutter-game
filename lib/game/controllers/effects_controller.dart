import 'dart:ui';

import '../models/game_effects.dart';
import '../models/obstacle_dot.dart';

/// Owns and ages transient visual effects.
class EffectsController {
  final List<FloatingText> texts = [];
  final List<DotFlash> flashes = [];
  final List<RingBurst> bursts = [];

  /// Penalties landing within this window from the same source merge into
  /// one number, so a dense cluster reads "-35" instead of a pile of "-5"s.
  static const _mergeWindow = 0.18;
  final Map<Object, FloatingText> _lastPenaltyText = {};

  void tick(double dt) {
    for (final e in texts) {
      e.age += dt;
    }
    for (final e in flashes) {
      e.age += dt;
    }
    for (final e in bursts) {
      e.age += dt;
    }
    texts.removeWhere((e) => e.isDone);
    flashes.removeWhere((e) => e.isDone);
    bursts.removeWhere((e) => e.isDone);
    _lastPenaltyText.removeWhere((_, t) => t.isDone);
  }

  void penalty({
    required Object source,
    required ObstacleDot dot,
    required int amount,
    required Color textColor,
    required Color flashColor,
  }) {
    flashes.add(DotFlash(dot: dot, color: flashColor));
    final recent = _lastPenaltyText[source];
    if (recent != null && recent.age < _mergeWindow) {
      recent.value += amount;
      recent.age = 0;
      recent.position = dot.center;
      return;
    }
    final text = FloatingText(
      position: dot.center,
      value: amount,
      color: textColor,
      prefix: '-',
    );
    texts.add(text);
    _lastPenaltyText[source] = text;
  }

  void floatText(
    Offset position,
    String prefix,
    int value,
    Color color, {
    double duration = 1.1,
  }) {
    texts.add(
      FloatingText(
        position: position,
        value: value,
        color: color,
        prefix: prefix,
        duration: duration,
      ),
    );
  }

  void burst(
    Offset position,
    Color color, {
    double maxRadius = 90,
    double duration = 0.7,
  }) {
    bursts.add(
      RingBurst(
        position: position,
        color: color,
        maxRadius: maxRadius,
        duration: duration,
      ),
    );
  }

  void clear() {
    texts.clear();
    flashes.clear();
    bursts.clear();
    _lastPenaltyText.clear();
  }
}
