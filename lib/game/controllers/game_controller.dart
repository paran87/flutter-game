import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../app/theme.dart';

import '../models/game_config.dart';
import '../models/game_state.dart';
import '../models/ink_trace.dart';
import '../models/obstacle_dot.dart';
import '../models/player.dart';
import '../models/player_identities.dart';
import '../services/game_feedback.dart';
import '../utils/obstacle_generator.dart';
import 'collision_controller.dart';
import 'effects_controller.dart';
import 'movement_controller.dart';
import 'player_agent.dart';
import 'scoring_controller.dart';

/// Central game state machine. Owns players, the obstacle field, the clock
/// and round progression. Widgets only read from it and forward input.
class GameController {
  GameController({
    this.config = const GameConfig(),
    required this.bottomAgent,
    required this.topAgent,
    GameFeedback? feedback,
  }) : feedback = feedback ?? GameFeedback.silent(),
       scoring = ScoringController(config),
       _baseSeed = config.obstacleSeed ?? math.Random().nextInt(1 << 30),
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
    _collisions = {for (final p in players) p: CollisionController(config)};
    _generateField();
    phase.value = GamePhase.playing;
    for (final p in players) {
      _startRun(p);
    }
  }

  final GameConfig config;
  final PlayerAgent bottomAgent;
  final PlayerAgent topAgent;
  final GameFeedback feedback;
  final ScoringController scoring;
  final EffectsController effects = EffectsController();
  final int _baseSeed;
  final MovementController _movement;
  late final Map<Player, CollisionController> _collisions;

  /// Simulated game time in seconds (advances only via [tick]).
  double _time = 0;
  double get time => _time;

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

  CollisionController collisionsFor(Player p) => _collisions[p]!;

  void _startRun(Player p) {
    p.resetToStart();
    _collisions[p]!.reset();
    agentFor(p).onRunStart(_contextFor(p));
    _publishHud(p);
  }

  /// Advances the simulation by [dt] seconds.
  void tick(double dt) {
    _time += dt;
    effects.tick(dt);
    for (final t in fadingTraces) {
      t.age += dt;
    }
    fadingTraces.removeWhere((t) => t.isDone);

    if (phase.value == GamePhase.playing) {
      for (final p in players) {
        _updatePlayer(p, dt);
      }
    }
    for (final p in players) {
      p.slowdownRemaining = math.max(0, p.slowdownRemaining - dt);
      p.shakeRemaining = math.max(0, p.shakeRemaining - dt);
      _publishHud(p);
    }
    frame.ping();
  }

  void _updatePlayer(Player p, double dt) {
    if (!p.canMove) return;
    final agent = agentFor(p);
    final intent = agent.update(dt, _contextFor(p));
    final target = intent.target;
    if (target == null) return;

    final from = p.position;
    p.position = _movement.step(
      position: from,
      target: target,
      dt: dt,
      maxSpeed: agent.maxSpeed,
      // Touching a dot briefly drags the pen, like ink catching on paper.
      speedFactor: p.slowdownRemaining > 0 ? config.collisionSlowdownFactor : 1,
    );

    // The run officially starts once the pen leaves the start pad.
    if (p.runStatus == RunStatus.ready &&
        (p.position - p.startPosition).distance > config.runStartThreshold) {
      p.runStatus = RunStatus.running;
    }
    if (p.runStatus == RunStatus.running) {
      // The same points feed the ballpoint rendering and distance tracking.
      p.trace.addPoint(p.position, minSpacing: config.minTracePointSpacing);
      p.run.distance = scoring.distanceFromWorld(p.trace.length);
    }
    _checkCollisions(p, from, p.position);
  }

  void _checkCollisions(Player p, Offset from, Offset to) {
    final hits = _collisions[p]!.step(field.value, from, to, _time);
    if (hits.isEmpty) return;
    for (final dot in hits) {
      final amount = scoring.applyPenalty(p, dot);
      effects.penalty(
        source: p,
        dot: dot,
        amount: amount,
        textColor: AppColors.penalty,
        flashColor: p.identity.color,
      );
    }
    // Feedback, but never a stop: the pen keeps moving.
    p.slowdownRemaining = config.collisionSlowdownDuration.inMicroseconds / 1e6;
    p.shakeRemaining = 0.22;
    feedback.obstacleTouched(local: !p.identity.isBot);
  }

  double inkFraction(Player p) =>
      (1 - p.trace.length / config.inkCapacity).clamp(0.0, 1.0);

  void _publishHud(Player p) {
    p.publishHud(liveScore: scoring.liveScore(p), inkFraction: inkFraction(p));
  }

  void dispose() {
    feedback.dispose();
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
