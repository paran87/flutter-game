import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../models/game_config.dart';
import '../models/game_state.dart';
import '../models/ink_trace.dart';
import '../models/obstacle_dot.dart';
import '../models/player.dart';
import '../models/player_identities.dart';
import '../utils/obstacle_generator.dart';
import 'movement_controller.dart';
import 'player_agent.dart';

/// Central game state machine. Owns players, the obstacle field, the clock
/// and round progression. Widgets only read from it and forward input.
class GameController {
  GameController({
    this.config = const GameConfig(),
    required this.bottomAgent,
    required this.topAgent,
  }) : _baseSeed = config.obstacleSeed ?? math.Random().nextInt(1 << 30),
       _movement = MovementController(config) {
    bottom = Player(
      side: PlayerSide.bottom,
      identity: humanIdentity,
      startPosition: config.bottomStart,
      balloons: config.balloonsPerPlayer,
      maxAttempts: config.attemptsPerPlayer,
    );
    top = Player(
      side: PlayerSide.top,
      identity: botIdentity(config.botDifficulty),
      startPosition: config.topStart,
      balloons: config.balloonsPerPlayer,
      maxAttempts: config.attemptsPerPlayer,
    );
    _generateField();
    phase.value = GamePhase.playing;
    for (final p in players) {
      _startRun(p);
    }
  }

  final GameConfig config;
  final PlayerAgent bottomAgent;
  final PlayerAgent topAgent;
  final int _baseSeed;
  final MovementController _movement;

  late final Player bottom;
  late final Player top;
  List<Player> get players => [bottom, top];

  /// Fires every simulated frame; painters repaint from it.
  final FrameSignal frame = FrameSignal();

  /// Fires when a new obstacle field is generated.
  final ValueNotifier<ObstacleField> field = ValueNotifier(
    ObstacleField.empty(Rect.zero),
  );

  /// Traces from failed runs that are fading away.
  final List<FadingTrace> fadingTraces = [];

  final ValueNotifier<GamePhase> phase = ValueNotifier(GamePhase.intro);
  final ValueNotifier<int> round = ValueNotifier(1);

  PlayerAgent agentFor(Player p) =>
      identical(p, bottom) ? bottomAgent : topAgent;
  Player opponentOf(Player p) => identical(p, bottom) ? top : bottom;

  AgentContext _contextFor(Player p) => AgentContext(
    config: config,
    field: field.value,
    self: p,
    opponent: opponentOf(p),
  );

  void _generateField() {
    // Each round gets its own layout, reproducible from the base seed.
    final seed = _baseSeed + (round.value - 1) * 7919;
    field.value = ObstacleGenerator(config).generate(seed);
  }

  void _startRun(Player p) {
    p.resetToStart();
    agentFor(p).onRunStart(_contextFor(p));
  }

  /// Advances the simulation by [dt] seconds.
  void tick(double dt) {
    for (final t in fadingTraces) {
      t.age += dt;
    }
    fadingTraces.removeWhere((t) => t.isDone);

    if (phase.value == GamePhase.playing) {
      for (final p in players) {
        _updatePlayer(p, dt);
      }
    }
    frame.ping();
  }

  void _updatePlayer(Player p, double dt) {
    if (!p.canMove) return;
    final agent = agentFor(p);
    final intent = agent.update(dt, _contextFor(p));
    final target = intent.target;
    if (target == null) return;

    p.position = _movement.step(
      position: p.position,
      target: target,
      dt: dt,
      maxSpeed: agent.maxSpeed,
    );

    // The run officially starts once the pen leaves the start pad.
    if (p.runStatus == RunStatus.ready &&
        (p.position - p.startPosition).distance > config.runStartThreshold) {
      p.runStatus = RunStatus.running;
    }
    if (p.runStatus == RunStatus.running) {
      // The same points feed the ballpoint rendering and distance tracking.
      p.trace.addPoint(p.position, minSpacing: config.minTracePointSpacing);
    }
  }

  void dispose() {
    frame.dispose();
    field.dispose();
    phase.dispose();
    round.dispose();
    bottomAgent.dispose();
    topAgent.dispose();
    for (final p in players) {
      p.dispose();
    }
  }
}

/// A listenable that is pinged once per simulated frame.
class FrameSignal extends ChangeNotifier {
  void ping() => notifyListeners();
}
