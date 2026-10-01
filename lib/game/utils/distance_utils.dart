import 'dart:math' as math;
import 'dart:ui';

/// Euclidean distance between two points.
double segmentLength(Offset a, Offset b) {
  final dx = b.dx - a.dx;
  final dy = b.dy - a.dy;
  return math.sqrt(dx * dx + dy * dy);
}

/// Cumulative length of a polyline: |AB| + |BC| + |CD| + ...
///
/// This is the path a pen actually travelled, so sideways and winding
/// movement counts — unlike a naive `endY - startY`.
double pathLength(List<Offset> points) {
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += segmentLength(points[i - 1], points[i]);
  }
  return total;
}
