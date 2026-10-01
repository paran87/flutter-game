import 'dart:ui';

import 'distance_utils.dart';

/// Chaikin corner cutting: each pass replaces every corner with two points
/// at 1/4 and 3/4 along its segments, turning a jagged grid path into a
/// smooth, natural-looking curve. Endpoints are kept.
List<Offset> chaikinSmooth(List<Offset> points, {int iterations = 2}) {
  var result = points;
  for (var n = 0; n < iterations; n++) {
    if (result.length < 3) return result;
    final next = <Offset>[result.first];
    for (var i = 0; i < result.length - 1; i++) {
      final a = result[i];
      final b = result[i + 1];
      next
        ..add(Offset.lerp(a, b, 0.25)!)
        ..add(Offset.lerp(a, b, 0.75)!);
    }
    next.add(result.last);
    result = next;
  }
  return result;
}

/// Resamples a polyline into points spaced [spacing] apart along its length.
List<Offset> resample(List<Offset> points, double spacing) {
  if (points.length < 2 || spacing <= 0) return List.of(points);
  final out = <Offset>[points.first];
  var carried = 0.0;
  for (var i = 1; i < points.length; i++) {
    var a = points[i - 1];
    final b = points[i];
    var segment = segmentLength(a, b);
    while (carried + segment >= spacing) {
      final t = (spacing - carried) / segment;
      a = Offset.lerp(a, b, t)!;
      out.add(a);
      segment = segmentLength(a, b);
      carried = 0;
    }
    carried += segment;
  }
  if (out.last != points.last) out.add(points.last);
  return out;
}
