import 'dart:ui';

/// Penalty tier of a dot, derived from its radius.
enum ObstacleSize { small, medium, large }

/// One ink dot in the obstacle field.
class ObstacleDot {
  const ObstacleDot({
    required this.id,
    required this.center,
    required this.radius,
    required this.opacity,
    required this.size,
    this.blobOffset = Offset.zero,
    this.blobScale = 0,
  });

  final int id;
  final Offset center;

  /// Collision and drawing radius (world units).
  final double radius;

  /// 0..1 ink darkness. Low values read as light-grey dots.
  final double opacity;
  final ObstacleSize size;

  /// Visual-only: a satellite blob that makes the dot look like a real ink
  /// blot instead of a perfect circle. Collision uses the main circle only.
  final Offset blobOffset;
  final double blobScale;
}

/// A generated field of dots plus a uniform grid for fast proximity queries.
class ObstacleField {
  ObstacleField({
    required this.dots,
    required this.bounds,
    required this.seed,
    this.cellSize = 40,
  }) {
    _columns = (bounds.width / cellSize).ceil() + 1;
    _rows = (bounds.height / cellSize).ceil() + 1;
    _cells = List.generate(_columns * _rows, (_) => <int>[]);
    for (var i = 0; i < dots.length; i++) {
      final d = dots[i];
      _maxRadius = d.radius > _maxRadius ? d.radius : _maxRadius;
      // Register the dot in every cell its circle overlaps.
      final c0 = _col(d.center.dx - d.radius);
      final c1 = _col(d.center.dx + d.radius);
      final r0 = _row(d.center.dy - d.radius);
      final r1 = _row(d.center.dy + d.radius);
      for (var r = r0; r <= r1; r++) {
        for (var c = c0; c <= c1; c++) {
          _cells[r * _columns + c].add(i);
        }
      }
    }
  }

  /// An empty field (used before the first round is generated).
  factory ObstacleField.empty(Rect bounds) =>
      ObstacleField(dots: const [], bounds: bounds, seed: 0);

  final List<ObstacleDot> dots;
  final Rect bounds;
  final int seed;
  final double cellSize;

  late final int _columns;
  late final int _rows;
  late final List<List<int>> _cells;
  double _maxRadius = 0;

  double get maxRadius => _maxRadius;

  int _col(double x) =>
      ((x - bounds.left) / cellSize).floor().clamp(0, _columns - 1);
  int _row(double y) =>
      ((y - bounds.top) / cellSize).floor().clamp(0, _rows - 1);

  /// Indexes of dots whose cells overlap [area]. May contain dots that are
  /// not actually inside [area]; callers do the precise test.
  Set<int> candidatesIn(Rect area) {
    final result = <int>{};
    if (!area.overlaps(bounds.inflate(_maxRadius))) return result;
    final c0 = _col(area.left);
    final c1 = _col(area.right);
    final r0 = _row(area.top);
    final r1 = _row(area.bottom);
    for (var r = r0; r <= r1; r++) {
      for (var c = c0; c <= c1; c++) {
        result.addAll(_cells[r * _columns + c]);
      }
    }
    return result;
  }
}
