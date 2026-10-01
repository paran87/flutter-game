import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../../app/theme.dart';
import '../models/game_config.dart';
import '../models/ink_trace.dart';

/// Renders [InkTrace]s as ballpoint-pen strokes.
///
/// How the look is built:
///   * Points are smoothed with quadratic curves through their midpoints,
///     so the line is one flowing curve, not a polyline.
///   * Each point gets a tiny, smoothly varying sideways offset (hand
///     tremor). It depends only on the point index, so it never "swims".
///   * The stroke is drawn as a slightly lighter body plus a darker, thinner
///     core, which reads like ballpoint ink pressed into paper.
///   * Width and ink density drift gently along the line (pen pressure).
///
/// Performance: a trace is split into fixed-size chunks. Completed chunks are
/// built once and cached; only the newest chunk is rebuilt each frame.
class TraceRenderer {
  TraceRenderer(this.config);

  final GameConfig config;
  static const _chunk = 24;

  final Map<int, _TraceCache> _cache = {};

  /// Paints [trace] in world coordinates (the canvas must already be scaled).
  /// [fade] 0..1 fades the ink toward the paper colour.
  void paint(Canvas canvas, InkTrace trace, Color color, {double fade = 0}) {
    final points = trace.points;
    if (points.length < 2) {
      _paintStartBlob(canvas, points.first, color, fade);
      return;
    }

    final cache = _cache.putIfAbsent(trace.id, () => _TraceCache());
    // A chunk can be finalised once the point after its end exists (needed
    // for the end point's tremor direction).
    while ((cache.chunks.length + 1) * _chunk + 1 < points.length) {
      final index = cache.chunks.length;
      cache.chunks.add(
        _buildChunk(trace, index * _chunk, (index + 1) * _chunk, index),
      );
    }

    _paintStartBlob(canvas, points.first, color, fade);
    for (final chunk in cache.chunks) {
      _strokeChunk(canvas, chunk, color, fade);
    }
    final liveStart = cache.chunks.length * _chunk;
    if (liveStart < points.length - 1) {
      _strokeChunk(
        canvas,
        _buildChunk(trace, liveStart, points.length - 1, cache.chunks.length),
        color,
        fade,
      );
    }
  }

  /// Forget cached geometry for traces that are no longer drawn.
  void retainOnly(Set<int> traceIds) {
    _cache.removeWhere((id, _) => !traceIds.contains(id));
  }

  _Chunk _buildChunk(InkTrace trace, int from, int to, int chunkIndex) {
    final pts = trace.points;
    final seed = trace.id * 13.37;
    Offset jittered(int i) {
      final p = pts[i];
      if (i == 0 || i >= pts.length - 1) return p;
      final dir = pts[i + 1] - pts[i - 1];
      final len = dir.distance;
      if (len == 0) return p;
      final normal = Offset(-dir.dy / len, dir.dx / len);
      // Smooth pseudo-noise from layered sines: slow wander + fine tremor.
      final n =
          math.sin(i * 0.23 + seed) * 0.65 +
          math.sin(i * 0.71 + seed * 1.9) * 0.35;
      return p + normal * (n * config.traceJitter);
    }

    final path = Path();
    var prev = jittered(from);
    path.moveTo(prev.dx, prev.dy);
    for (var i = from + 1; i < to; i++) {
      final current = jittered(i);
      final next = jittered(i + 1);
      final mid = Offset(
        (current.dx + next.dx) / 2,
        (current.dy + next.dy) / 2,
      );
      path.quadraticBezierTo(current.dx, current.dy, mid.dx, mid.dy);
      prev = current;
    }
    final end = jittered(to);
    path.lineTo(end.dx, end.dy);

    // Pen pressure drifts slowly from chunk to chunk.
    final pressure = 0.5 + 0.5 * math.sin(chunkIndex * 0.9 + seed);

    // Like a real ballpoint running dry, the last 20% of the ink gets
    // visibly fainter — a natural warning that the run is about to fail.
    final used = trace.length * (from / (pts.length - 1)) / config.inkCapacity;
    final starvation = ((used - 0.8) / 0.2).clamp(0.0, 1.0);
    return _Chunk(
      path,
      widthFactor: (0.88 + 0.24 * pressure) * (1 - 0.3 * starvation),
      inkFactor: (0.84 + 0.16 * pressure) * (1 - 0.55 * starvation),
    );
  }

  void _strokeChunk(Canvas canvas, _Chunk chunk, Color color, double fade) {
    final ink = config.traceOpacity * chunk.inkFactor * (1 - fade);
    if (ink <= 0.01) return;
    final width = config.traceWidth * chunk.widthFactor;

    // Colours are mixed with the paper rather than made transparent, so the
    // round caps where chunks meet never double-darken into blobs.
    final body = Color.lerp(AppColors.paper, color, ink * 0.78)!;
    final core = Color.lerp(
      AppColors.paper,
      Color.lerp(color, AppColors.ink, 0.25)!,
      ink,
    )!;

    canvas.drawPath(
      chunk.path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = body,
    );
    canvas.drawPath(
      chunk.path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 0.42
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = core,
    );
  }

  /// Ballpoints leave a small blob where the pen first touches the paper.
  void _paintStartBlob(Canvas canvas, Offset p, Color color, double fade) {
    final ink = config.traceOpacity * (1 - fade);
    if (ink <= 0.01) return;
    canvas.drawCircle(
      p,
      config.traceWidth * 0.95,
      Paint()..color = Color.lerp(AppColors.paper, color, ink * 0.9)!,
    );
  }
}

class _TraceCache {
  final List<_Chunk> chunks = [];
}

class _Chunk {
  _Chunk(this.path, {required this.widthFactor, required this.inkFactor});

  final Path path;
  final double widthFactor;
  final double inkFactor;
}
