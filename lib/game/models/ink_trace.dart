import 'dart:ui';

import '../utils/distance_utils.dart';

/// The ordered points a pen actually travelled through during one run.
///
/// The same points drive both the ballpoint rendering and the distance
/// measurement, so what you see is exactly what you are scored on.
class InkTrace {
  InkTrace({required this.id, required Offset start}) : _points = [start];

  /// Unique id; lets renderers cache per-trace geometry.
  final int id;
  final List<Offset> _points;
  double _length = 0;

  List<Offset> get points => _points;

  /// Cumulative polyline length in world units.
  double get length => _length;

  Offset get last => _points.last;

  /// Appends [point] if it is at least [minSpacing] from the last point.
  /// Returns the length added (0 if the point was skipped).
  double addPoint(Offset point, {double minSpacing = 0}) {
    final step = segmentLength(_points.last, point);
    if (step < minSpacing || step == 0) return 0;
    _points.add(point);
    _length += step;
    return step;
  }
}

/// A trace that is fading away (e.g. after a failed run).
class FadingTrace {
  FadingTrace(this.trace, this.color, this.duration);

  final InkTrace trace;
  final Color color;
  final double duration;
  double age = 0;

  double get progress => (age / duration).clamp(0.0, 1.0);
  bool get isDone => age >= duration;
}
