import 'package:flutter/services.dart';

/// Subtle haptics, all routed through one switch so they are easy to disable.
class HapticsService {
  HapticsService({this.enabled = true});

  bool enabled;

  void light() {
    if (enabled) HapticFeedback.lightImpact();
  }

  void medium() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  void heavy() {
    if (enabled) HapticFeedback.heavyImpact();
  }

  void selection() {
    if (enabled) HapticFeedback.selectionClick();
  }
}
