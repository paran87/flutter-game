import 'dart:ui';

/// Squared distance from point [p] to the segment [a]–[b].
double distanceToSegmentSquared(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final lengthSquared = ab.distanceSquared;
  if (lengthSquared == 0) return (p - a).distanceSquared;
  // Project p onto the segment and clamp to its ends.
  var t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lengthSquared;
  t = t.clamp(0.0, 1.0);
  final closest = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
  return (p - closest).distanceSquared;
}

/// Whether a pen of [penRadius] sweeping from [from] to [to] touches a
/// circle at [center] with [radius]. Sweeping (instead of testing only the
/// end point) means a fast pen can never tunnel through a small dot.
bool sweptCircleHits({
  required Offset from,
  required Offset to,
  required double penRadius,
  required Offset center,
  required double radius,
  double tolerance = 0,
}) {
  final reach = penRadius + radius - tolerance;
  if (reach <= 0) return false;
  return distanceToSegmentSquared(center, from, to) <= reach * reach;
}
