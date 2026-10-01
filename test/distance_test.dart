import 'package:dotline_duel/game/models/ink_trace.dart';
import 'package:dotline_duel/game/utils/distance_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pathLength', () {
    test('sums every segment, not just vertical progress', () {
      // A zig-zag that ends level with where it started still has length.
      const points = [Offset(0, 0), Offset(30, 40), Offset(60, 0)];
      expect(pathLength(points), closeTo(100, 1e-9));
    });

    test('sideways and diagonal movement counts', () {
      const points = [Offset(0, 0), Offset(100, 0), Offset(100, 100)];
      expect(pathLength(points), closeTo(200, 1e-9));
    });

    test('empty and single-point paths have zero length', () {
      expect(pathLength(const []), 0);
      expect(pathLength(const [Offset(5, 5)]), 0);
    });
  });

  group('InkTrace', () {
    test('length equals the polyline length of its stored points', () {
      final trace = InkTrace(id: 1, start: Offset.zero);
      const steps = [Offset(3, 4), Offset(6, 8), Offset(6, 20), Offset(0, 20)];
      for (final p in steps) {
        trace.addPoint(p);
      }
      expect(trace.length, closeTo(pathLength(trace.points), 1e-9));
      expect(trace.length, closeTo(5 + 5 + 12 + 6, 1e-9));
    });

    test('points closer than min spacing are skipped (no distance farmed)', () {
      final trace = InkTrace(id: 2, start: Offset.zero);
      expect(trace.addPoint(const Offset(1, 0), minSpacing: 2.5), 0);
      expect(trace.points.length, 1);
      expect(trace.addPoint(const Offset(3, 0), minSpacing: 2.5), 3);
      expect(trace.points.length, 2);
    });
  });
}
