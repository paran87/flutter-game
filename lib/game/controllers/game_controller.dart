import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../app/theme.dart';
import '../models/balloon.dart';
import '../models/game_config.dart';
import '../models/game_state.dart';
import '../models/game_stats.dart';
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

/// A successful crossing, shown in the "RUN COMPLETE" card.
class RunSuccess {
  const RunSuccess(this.player, this.summary);

  final Player player;
  final RunSummary summary;
}

/// A failed run, shown as a toast near that player's side.
class RunFailure {
  const RunFailure(this.player, this.reason, this.serial);

  final Player player;
  final FailureReason reason;

  /// Increments per failure so identical consecutive failures still notify.
  final int serial;
}

/// Central game state machine. Owns players, the obstacle field, the clock
/// and round progression. Widgets only read from it and forward input.
///
/// Flow of a round:
///
///   intro/nextRound → countdown → playing ──(someone crosses)──► playerSuccess
///        ▲                          │                                │
///        │                     (run fails: that player resets,       ▼
///        │                      the other keeps racing)          targeting
///        │                                                           │
///        └────────────── nextRound ◄──── balloonDestroyed ◄──────────┘
///                                              │
///                                   (all balloons gone) ──► gameOver
///
/// All timing is driven by [tick], so the whole match can be simulated
/// headlessly in tests.
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
    for (final p in players) {
      _startRun(p);
    }
    _setPhase(GamePhase.playing);
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

  /// The most recent crossing (drives the run summary card).
  final ValueNotifier<RunSuccess?> lastSuccess = ValueNotifier(null);

  /// The most recent failed run (drives failure toasts).
  final ValueNotifier<RunFailure?> lastFailure = ValueNotifier(null);
  int _failureSerial = 0;

  /// Simulated game time in seconds (advances only via [tick]).
  double _time = 0;
  double get time => _time;

  /// Seconds spent in the current [phase].
  double _phaseTime = 0;
  double get phaseTime => _phaseTime;

  /// The player who crossed this round (attacker during targeting).
  Player? _roundWinner;
  Player? get roundWinner => _roundWinner;

  /// Balloon chosen during targeting (index into the defender's balloons).
  int? _targetIndex;
  int? get targetIndex => _targetIndex;

  /// Bumped whenever any balloon changes status, so balloon widgets rebuild
  /// only then.
  final ValueNotifier<int> balloonVersion = ValueNotifier(0);

  /// Brief lock-on before the pop, so the choice reads as intentional.
  static const _lockOnSeconds = 0.35;

  PlayerAgent agentFor(Player p) =>
      identical(p, bottom) ? bottomAgent : topAgent;
  Player opponentOf(Player p) => identical(p, bottom) ? top : bottom;
  CollisionController collisionsFor(Player p) => _collisions[p]!;

  bool get isPlaying => phase.value == GamePhase.playing;

  AgentContext _contextFor(Player p) => AgentContext(
    config: config,
    field: field.value,
    self: p,
    opponent: opponentOf(p),
  );

  // ------------------------------------------------------------ Lifecycle

  void _setPhase(GamePhase next) {
    _phaseTime = 0;
    phase.value = next;
  }

  void _generateField() {
    // Each round gets its own layout, reproducible from the base seed.
    final seed = _baseSeed + (round.value - 1) * 7919;
    field.value = ObstacleGenerator(config).generate(seed);
  }

  void _startRun(Player p) {
    p.resetToStart();
    _collisions[p]!.reset();
    agentFor(p).onRunStart(_contextFor(p));
    _publishHud(p);
  }

  /// Advances the simulation by [dt] seconds.
  void tick(double dt) {
    _time += dt;
    _phaseTime += dt;
    effects.tick(dt);
    for (final t in fadingTraces) {
      t.age += dt;
    }
    fadingTraces.removeWhere((t) => t.isDone);

    switch (phase.value) {
      case GamePhase.playing:
        _tickPlaying(dt);
      case GamePhase.playerSuccess:
        if (_phaseTime >= _seconds(config.successSummaryDuration)) {
          _beginTargeting();
        }
      case GamePhase.targeting:
        _tickTargeting();
      case GamePhase.balloonDestroyed:
        _tickBalloonDestroyed();
      case GamePhase.intro:
      case GamePhase.countdown:
      case GamePhase.nextRound:
      case GamePhase.gameOver:
        break;
    }

    for (final p in players) {
      p.slowdownRemaining = math.max(0, p.slowdownRemaining - dt);
      p.shakeRemaining = math.max(0, p.shakeRemaining - dt);
      _publishHud(p);
    }
    frame.ping();
  }

  void _tickPlaying(double dt) {
    for (final p in players) {
      switch (p.runStatus) {
        case RunStatus.ready:
        case RunStatus.running:
          _updatePlayer(p, dt);
        case RunStatus.failed:
          p.statusTime += dt;
          if (p.statusTime >= _seconds(config.failureResetDuration)) {
            _startRun(p);
          }
        case RunStatus.finished:
        case RunStatus.halted:
        case RunStatus.eliminated:
          break;
      }
      // A crossing ends the round immediately for both players.
      if (!isPlaying) return;
    }
    if (bottom.runStatus == RunStatus.eliminated &&
        top.runStatus == RunStatus.eliminated) {
      _endGame(GameEndTrigger.noAttempts);
    }
  }

  // ------------------------------------------------------------- Movement

  void _updatePlayer(Player p, double dt) {
    final agent = agentFor(p);
    final intent = agent.update(dt, _contextFor(p));

    // Lifting the pen mid-run starts a grace countdown.
    if (p.runStatus == RunStatus.running && !intent.penDown) {
      p.penLiftedFor += dt;
      if (config.penLiftFailsRun &&
          p.penLiftedFor >= _seconds(config.penLiftGracePeriod)) {
        _failRun(p, FailureReason.penLifted);
      }
      return;
    }
    p.penLiftedFor = 0;

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
    if (p.runStatus != RunStatus.running) return;

    // The same points feed the ballpoint rendering and distance tracking.
    p.trace.addPoint(p.position, minSpacing: config.minTracePointSpacing);
    p.run.distance = scoring.distanceFromWorld(p.trace.length);
    _checkCollisions(p, from, p.position);

    if (_reachedGoal(p)) {
      _succeedRun(p);
    } else if (p.trace.length >= config.inkCapacity) {
      _failRun(p, FailureReason.outOfInk);
    }
  }

  bool _reachedGoal(Player p) => p.isTop
      ? p.position.dy >= config.topGoalY
      : p.position.dy <= config.bottomGoalY;

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
    p.slowdownRemaining = _seconds(config.collisionSlowdownDuration);
    p.shakeRemaining = 0.22;
    feedback.obstacleTouched(local: !p.identity.isBot);
  }

  // ------------------------------------------------------- Run outcomes

  void _succeedRun(Player p) {
    p.runStatus = RunStatus.finished;
    p.stats.successfulRuns++;
    final summary = scoring.closeRun(p, bank: true);
    _roundWinner = p;
    lastSuccess.value = RunSuccess(p, summary);
    effects.burst(p.position, p.identity.color, maxRadius: 120, duration: 0.9);
    feedback.runSucceeded(local: !p.identity.isBot);

    // The other player's run is cut short by the crossing.
    final other = opponentOf(p);
    if (other.runStatus == RunStatus.running ||
        other.runStatus == RunStatus.ready) {
      scoring.closeRun(other, bank: config.bankInterruptedRunScore);
      other.runStatus = RunStatus.halted;
    }
    _setPhase(GamePhase.playerSuccess);
  }

  void _failRun(Player p, FailureReason reason) {
    p.runStatus = RunStatus.failed;
    p.failureReason = reason;
    p.statusTime = 0;
    p.attemptsRemaining = math.max(0, p.attemptsRemaining - 1);
    p.stats.failedRuns++;
    scoring.closeRun(p, bank: false);

    // The failed line fades away; cumulative stats are kept.
    fadingTraces.add(
      FadingTrace(
        p.trace,
        p.identity.color,
        _seconds(config.failureResetDuration),
      ),
    );
    p.beginFreshTrace();
    effects.burst(p.position, AppColors.danger, maxRadius: 70);
    lastFailure.value = RunFailure(p, reason, ++_failureSerial);
    feedback.runFailed(local: !p.identity.isBot);
  }

  // ------------------------------------------------------------ Targeting

  /// The player whose balloons are under attack.
  Player? get defender {
    final attacker = _roundWinner;
    return attacker == null ? null : opponentOf(attacker);
  }

  void _beginTargeting() {
    final attacker = _roundWinner!;
    agentFor(attacker).reset();
    _targetIndex = null;
    _setPhase(GamePhase.targeting);
  }

  void _tickTargeting() {
    final attacker = _roundWinner!;
    final target = defender!;
    final available = target.aliveBalloonIndexes;

    if (_targetIndex == null) {
      var choice = agentFor(attacker).chooseBalloon(available, _phaseTime);
      // Nobody waits forever: pick for an idle attacker when time runs out.
      if (choice == null &&
          _phaseTime >= _seconds(config.targetingDuration) &&
          available.isNotEmpty) {
        choice = available[math.Random().nextInt(available.length)];
      }
      if (choice != null && available.contains(choice)) {
        _targetIndex = choice;
        target.balloons[choice].status = BalloonStatus.targeted;
        _lockOnAt = _phaseTime;
        balloonVersion.value++;
        feedback.haptics.selection();
      }
      return;
    }

    if (_phaseTime - _lockOnAt >= _lockOnSeconds) {
      target.balloons[_targetIndex!].status = BalloonStatus.popping;
      balloonVersion.value++;
      _popFeedbackDone = false;
      _setPhase(GamePhase.balloonDestroyed);
    }
  }

  double _lockOnAt = 0;
  bool _popFeedbackDone = false;

  /// Fraction of the pop animation at which the balloon visibly bursts
  /// (matches BalloonPainter's anticipation timing).
  static const _burstFraction = 0.52;

  void _tickBalloonDestroyed() {
    final attacker = _roundWinner!;
    final target = defender!;
    final balloon = target.balloons[_targetIndex!];
    final popTime = _seconds(config.balloonAnimationDuration);

    if (!_popFeedbackDone && _phaseTime >= popTime * _burstFraction) {
      _popFeedbackDone = true;
      feedback.balloonDestroyed(localOwner: !target.identity.isBot);
    }

    if (balloon.status == BalloonStatus.popping && _phaseTime >= popTime) {
      balloon.status = BalloonStatus.destroyed;
      attacker.stats.balloonsDestroyed++;
      balloonVersion.value++;
    }
    if (_phaseTime >= popTime + _seconds(config.postPopPause)) {
      if (target.balloonsStanding == 0) {
        _endGame(GameEndTrigger.balloons);
      } else {
        _beginNextRound();
      }
    }
  }

  // --------------------------------------------------------------- Rounds

  void _beginNextRound() {
    round.value++;
    _roundWinner = null;
    _targetIndex = null;
    _generateField();
    effects.clear();
    fadingTraces.clear();
    for (final p in players) {
      agentFor(p).reset();
      _startRun(p);
    }
    _setPhase(GamePhase.playing);
  }

  // ------------------------------------------------------------- Game end

  GameEndTrigger? _endTrigger;
  GameEndTrigger? get endTrigger => _endTrigger;

  void _endGame(GameEndTrigger trigger) {
    _endTrigger = trigger;
    for (final p in players) {
      agentFor(p).reset();
    }
    _setPhase(GamePhase.gameOver);
  }

  // ------------------------------------------------------------------ HUD

  double inkFraction(Player p) =>
      (1 - p.trace.length / config.inkCapacity).clamp(0.0, 1.0);

  void _publishHud(Player p) {
    p.publishHud(liveScore: scoring.liveScore(p), inkFraction: inkFraction(p));
  }

  static double _seconds(Duration d) => d.inMicroseconds / 1e6;

  void dispose() {
    feedback.dispose();
    frame.dispose();
    field.dispose();
    phase.dispose();
    round.dispose();
    lastSuccess.dispose();
    lastFailure.dispose();
    balloonVersion.dispose();
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
