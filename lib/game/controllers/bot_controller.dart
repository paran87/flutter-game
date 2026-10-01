import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../models/game_config.dart';
import '../models/obstacle_dot.dart';
import '../utils/path_utils.dart';
import 'player_agent.dart';

/// The AI opponent.
///
/// It is just another [PlayerAgent]: it only produces a target point and
/// pen state each frame, so it moves, collides and scores under exactly the
/// same rules as the human. Replacing it with a networked player means
/// writing another PlayerAgent — nothing else changes.
///
/// How it plays:
///  1. At the start of each run it builds a cost grid over the board:
///     cells near dots are expensive (weighted by dot size and by the
///     difficulty's `obstacleAvoidance`), plus random noise for sloppier
///     bots.
///  2. Grid A* finds a cheap route from its start to the goal line.
///  3. The route is smoothed (Chaikin) and resampled.
///  4. Each frame it chases a "carrot" a little ahead on that route, with a
///     sideways hand wobble, after a short human-like reaction delay.
class BotController extends PlayerAgent {
  BotController({required this.difficulty, this.seed});

  final BotDifficulty difficulty;

  /// Optional seed for reproducible behaviour (tests).
  final int? seed;

  BotProfile get profile => GameConfig.botProfileFor(difficulty);

  @override
  double get maxSpeed => profile.speed;

  math.Random _rng = math.Random();
  List<Offset> _path = const [];
  int _carrot = 0;
  double _runTime = 0;
  double _wobblePhase = 0;
  int _runCount = 0;

  /// The smoothed route the bot is following (for the debug overlay).
  List<Offset> get plannedPath => _path;

  @override
  void onRunStart(AgentContext context) {
    _runCount++;
    _rng = math.Random((seed ?? context.field.seed) * 31 + _runCount);
    _runTime = 0;
    _carrot = 0;
    _wobblePhase = _rng.nextDouble() * math.pi * 2;
    _path = _planPath(context);
  }

  @override
  AgentIntent update(double dt, AgentContext context) {
    _runTime += dt;
    // Reaction time: a beat before the pen starts moving.
    if (_runTime < profile.reactionDelay || _path.isEmpty) {
      return const AgentIntent(penDown: true);
    }

    final self = context.self.position;
    // Keep the carrot far enough ahead that easing never throttles the pen
    // below its speed cap, but close enough to follow the route's curves.
    final lookahead = math.max(
      26.0,
      profile.speed / context.config.movementSmoothing * 1.4,
    );
    while (_carrot < _path.length - 1 &&
        (_path[_carrot] - self).distance < lookahead) {
      _carrot++;
    }
    final carrot = _path[_carrot];

    // Sideways wobble, like a hand that isn't perfectly steady.
    final next = _path[math.min(_carrot + 1, _path.length - 1)];
    final prev = _path[math.max(_carrot - 1, 0)];
    final dir = next - prev;
    final len = dir.distance;
    var target = carrot;
    if (len > 0) {
      final normal = Offset(-dir.dy / len, dir.dx / len);
      final t = _runTime * profile.wobbleFrequency * math.pi * 2 + _wobblePhase;
      final wobble = math.sin(t) * 0.75 + math.sin(t * 2.3 + 1) * 0.25;
      target += normal * (wobble * profile.wobbleAmplitude);
    }
    return AgentIntent(target: target, penDown: true);
  }

  int? _aim;

  @override
  int? get aimHint => _aim;

  @override
  int? chooseBalloon(List<int> available, double elapsed) {
    if (available.isEmpty) return null;
    // A short "aiming" pause, sweeping across the targets, makes the choice
    // feel deliberate rather than instantaneous.
    if (elapsed < profile.targetDelay) {
      _aim = available[(elapsed / 0.28).floor() % available.length];
      return null;
    }
    return _aim = available[_rng.nextInt(available.length)];
  }

  @override
  void reset() => _aim = null;

  // ---------------------------------------------------------- Pathfinding

  List<Offset> _planPath(AgentContext context) {
    final config = context.config;
    final grid = _CostGrid.build(
      config: config,
      field: context.field,
      avoidance: profile.obstacleAvoidance,
      noise: profile.pathNoise,
      rng: _rng,
    );
    final start = context.self.startPosition;
    final goingDown = context.self.isTop;
    // Aim a little past the goal line so the bot commits to crossing it.
    final goalY = goingDown ? context.goalY + 25 : context.goalY - 25;

    final cells = grid.aStar(start, goalY: goalY, goingDown: goingDown);
    if (cells.isEmpty) {
      // Should not happen on an open board, but never leave the bot stuck.
      return [start, Offset(start.dx, goalY)];
    }
    final raw = [start, ...cells.skip(1), Offset(cells.last.dx, goalY)];
    return resample(chaikinSmooth(raw, iterations: 3), 8);
  }
}

/// Coarse cost map + A* used by the bot.
class _CostGrid {
  _CostGrid(this.cell, this.cols, this.rows, this.cost);

  final double cell;
  final int cols;
  final int rows;

  /// Movement cost per world unit for each cell (>= 1).
  final Float64List cost;

  static _CostGrid build({
    required GameConfig config,
    required ObstacleField field,
    required double avoidance,
    required double noise,
    required math.Random rng,
  }) {
    final cell = config.botPathCellSize;
    final cols = (config.worldWidth / cell).ceil();
    final rows = (config.worldHeight / cell).ceil();
    final danger = Float64List(cols * rows);
    final reachPad = config.playerRadius;
    const margin = 14.0;

    // Stamp each dot onto the cells around it.
    for (final dot in field.dots) {
      final weight = switch (dot.size) {
        ObstacleSize.small => 0.5,
        ObstacleSize.medium => 1.0,
        ObstacleSize.large => 2.0,
      };
      final reach = dot.radius + reachPad + margin;
      final c0 = math.max(0, ((dot.center.dx - reach) / cell).floor());
      final c1 = math.min(cols - 1, ((dot.center.dx + reach) / cell).floor());
      final r0 = math.max(0, ((dot.center.dy - reach) / cell).floor());
      final r1 = math.min(rows - 1, ((dot.center.dy + reach) / cell).floor());
      for (var r = r0; r <= r1; r++) {
        for (var c = c0; c <= c1; c++) {
          final center = Offset((c + 0.5) * cell, (r + 0.5) * cell);
          final gap = (center - dot.center).distance - dot.radius - reachPad;
          if (gap < 0) {
            danger[r * cols + c] += weight;
          } else if (gap < margin) {
            danger[r * cols + c] += weight * 0.35 * (1 - gap / margin);
          }
        }
      }
    }

    final cost = Float64List(cols * rows);
    for (var i = 0; i < cost.length; i++) {
      cost[i] = 1 + avoidance * danger[i] + noise * rng.nextDouble();
    }
    return _CostGrid(cell, cols, rows, cost);
  }

  Offset _center(int index) =>
      Offset((index % cols + 0.5) * cell, (index ~/ cols + 0.5) * cell);

  int _indexOf(Offset p) {
    final c = (p.dx / cell).floor().clamp(0, cols - 1);
    final r = (p.dy / cell).floor().clamp(0, rows - 1);
    return r * cols + c;
  }

  /// A* from [start] to any cell beyond [goalY] (8-connected).
  List<Offset> aStar(
    Offset start, {
    required double goalY,
    required bool goingDown,
  }) {
    final startIndex = _indexOf(start);
    final g = Float64List(cols * rows)
      ..fillRange(0, cols * rows, double.infinity);
    final cameFrom = Int32List(cols * rows)..fillRange(0, cols * rows, -1);
    final closed = Uint8List(cols * rows);
    g[startIndex] = 0;

    bool isGoal(int i) {
      final y = _center(i).dy;
      return goingDown ? y >= goalY : y <= goalY;
    }

    // Admissible heuristic: remaining vertical distance at minimum cost 1.
    double h(int i) =>
        math.max(0, goingDown ? goalY - _center(i).dy : _center(i).dy - goalY);

    final open = _MinHeap()..push(startIndex, h(startIndex));
    const dirs = [
      (-1, 0),
      (1, 0),
      (0, -1),
      (0, 1),
      (-1, -1),
      (1, -1),
      (-1, 1),
      (1, 1),
    ];

    while (open.isNotEmpty) {
      final current = open.pop();
      if (closed[current] == 1) continue;
      closed[current] = 1;
      if (isGoal(current)) return _reconstruct(cameFrom, current);

      final cc = current % cols;
      final cr = current ~/ cols;
      for (final (dc, dr) in dirs) {
        final nc = cc + dc;
        final nr = cr + dr;
        if (nc < 0 || nr < 0 || nc >= cols || nr >= rows) continue;
        final next = nr * cols + nc;
        if (closed[next] == 1) continue;
        final stepLength = (dc != 0 && dr != 0 ? math.sqrt2 : 1.0) * cell;
        final tentative =
            g[current] + stepLength * (cost[current] + cost[next]) / 2;
        if (tentative < g[next]) {
          g[next] = tentative;
          cameFrom[next] = current;
          open.push(next, tentative + h(next));
        }
      }
    }
    return const [];
  }

  List<Offset> _reconstruct(Int32List cameFrom, int end) {
    final out = Queue<Offset>();
    for (var i = end; i != -1; i = cameFrom[i]) {
      out.addFirst(_center(i));
    }
    return out.toList();
  }
}

/// Minimal binary min-heap of (index, priority).
class _MinHeap {
  final List<int> _items = [];
  final List<double> _priorities = [];

  bool get isNotEmpty => _items.isNotEmpty;

  void push(int item, double priority) {
    _items.add(item);
    _priorities.add(priority);
    var i = _items.length - 1;
    while (i > 0) {
      final parent = (i - 1) >> 1;
      if (_priorities[parent] <= _priorities[i]) break;
      _swap(i, parent);
      i = parent;
    }
  }

  int pop() {
    final top = _items.first;
    final lastItem = _items.removeLast();
    final lastPriority = _priorities.removeLast();
    if (_items.isNotEmpty) {
      _items[0] = lastItem;
      _priorities[0] = lastPriority;
      var i = 0;
      while (true) {
        final l = i * 2 + 1;
        final r = l + 1;
        var smallest = i;
        if (l < _items.length && _priorities[l] < _priorities[smallest]) {
          smallest = l;
        }
        if (r < _items.length && _priorities[r] < _priorities[smallest]) {
          smallest = r;
        }
        if (smallest == i) break;
        _swap(i, smallest);
        i = smallest;
      }
    }
    return top;
  }

  void _swap(int a, int b) {
    final item = _items[a];
    _items[a] = _items[b];
    _items[b] = item;
    final p = _priorities[a];
    _priorities[a] = _priorities[b];
    _priorities[b] = p;
  }
}
