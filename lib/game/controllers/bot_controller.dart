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
///  2. It picks one of your living balloons — Easy at random, Normal/Hard
///     whichever is cheapest to reach — and grid A* finds a route from its
///     start, through the dots and over your line, right into that balloon.
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
  List<Offset> get debugPath => _path;

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
      profile.speed / context.config.movementSmoothing * 1.0,
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

  // ---------------------------------------------------------- Pathfinding

  /// Index of the balloon the current run is aiming for (debug/tests).
  int? targetBalloon;

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
    final targets = context.opponent.aliveBalloonIndexes;
    if (targets.isEmpty) return const [];

    // Easy bots go for any balloon; better bots take the cheapest route.
    final candidates = difficulty == BotDifficulty.easy
        ? [targets[_rng.nextInt(targets.length)]]
        : targets;
    _Route? best;
    for (final index in candidates) {
      final route = grid.aStar(start, context.opponentBalloon(index));
      if (route != null && (best == null || route.cost < best.cost)) {
        best = route..balloon = index;
      }
    }

    if (best == null) {
      // Should not happen on an open board, but never leave the bot stuck.
      targetBalloon = targets.first;
      return [start, context.opponentBalloon(targets.first)];
    }
    targetBalloon = best.balloon;
    final goal = context.opponentBalloon(best.balloon);
    final cells = best.cells;
    final middle = cells.length > 2
        ? cells.sublist(1, cells.length - 1)
        : <Offset>[];
    final raw = [start, ...middle, goal];
    return resample(chaikinSmooth(raw, iterations: 3), 8);
  }
}

class _Route {
  _Route(this.cells, this.cost);

  final List<Offset> cells;
  final double cost;
  int balloon = 0;
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
    final minX = config.fieldRect.left + config.playerRadius;
    final maxX = config.fieldRect.right - config.playerRadius;
    for (var i = 0; i < cost.length; i++) {
      final x = (i % cols + 0.5) * cell;
      // Pens are clamped to the field's width, so cells outside it are walls.
      cost[i] = x < minX || x > maxX
          ? double.infinity
          : 1 + avoidance * danger[i] + noise * rng.nextDouble();
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

  /// A* from [start] to the cell containing [goal] (8-connected).
  _Route? aStar(Offset start, Offset goal) {
    final startIndex = _indexOf(start);
    final goalIndex = _indexOf(goal);
    final g = Float64List(cols * rows)
      ..fillRange(0, cols * rows, double.infinity);
    final cameFrom = Int32List(cols * rows)..fillRange(0, cols * rows, -1);
    final closed = Uint8List(cols * rows);
    g[startIndex] = 0;

    // Admissible heuristic: straight-line distance at the minimum cost of 1.
    double h(int i) => (_center(i) - goal).distance;

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
      if (current == goalIndex) {
        return _Route(_reconstruct(cameFrom, current), g[current]);
      }

      final cc = current % cols;
      final cr = current ~/ cols;
      for (final (dc, dr) in dirs) {
        final nc = cc + dc;
        final nr = cr + dr;
        if (nc < 0 || nr < 0 || nc >= cols || nr >= rows) continue;
        final next = nr * cols + nc;
        if (closed[next] == 1 || cost[next].isInfinite) continue;
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
    return null;
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
