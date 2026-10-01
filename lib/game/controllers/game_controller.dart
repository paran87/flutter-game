import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../app/theme.dart';
import '../models/balloon.dart';
import '../models/game_config.dart';
import '../models/game_result.dart';
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
import 'timer_controller.dart';
import 'win_resolver.dart';

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
    timer = TimerController(
      duration: config.gameDuration,
      warningSeconds: config.timerWarningSeconds,
      criticalSeconds: config.timerCriticalSeconds,
    );
    timerSeconds = ValueNotifier(timer.displaySeconds);
    _generateField();
    for (final p in players) {
      _startRun(p);
    }
    _setPhase(GamePhase.intro);
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

  /// The match clock; it only runs while players are racing.
  late final TimerController timer;

  /// Whole seconds left, for the HUD (notifies once per second).
  late final ValueNotifier<int> timerSeconds;

  /// Final result, set when the game ends.
  final ValueNotifier<GameResult?> result = ValueNotifier(null);

  /// While paused nothing advances: no movement, no clock, no animations.
  bool _paused = false;
  bool get isPaused => _paused;

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

  /// The defender balloon the attacker is currently eyeing (aim sweep).
  final ValueNotifier<int?> aimingAt = ValueNotifier(null);

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
    if (_paused) return;
    _time += dt;
    _phaseTime += dt;
    effects.tick(dt);
    for (final t in fadingTraces) {
      t.age += dt;
    }
    fadingTraces.removeWhere((t) => t.isDone);

    switch (phase.value) {
      case GamePhase.intro:
      case GamePhase.nextRound:
        final hold = phase.value == GamePhase.intro
            ? config.introDuration
            : config.nextRoundDuration;
        if (_phaseTime >= _seconds(hold)) _beginCountdown();
      case GamePhase.countdown:
        _tickCountdown();
      case GamePhase.playing:
        _tickClock(dt);
        if (isPlaying) _tickPlaying(dt);
      case GamePhase.playerSuccess:
        if (_phaseTime >= _seconds(config.successSummaryDuration)) {
          _beginTargeting();
        }
      case GamePhase.targeting:
        _tickTargeting();
      case GamePhase.balloonDestroyed:
        _tickBalloonDestroyed();
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

  // ------------------------------------------------------ Countdown/clock

  /// Number currently shown by the countdown (3, 2, 1), or 0 for "GO!".
  int get countdownValue {
    if (phase.value != GamePhase.countdown) return 0;
    final step = _seconds(config.countdownStep);
    return math.max(0, config.countdownSteps - (_phaseTime / step).floor());
  }

  int _lastCountdownValue = 0;

  void _beginCountdown() {
    _setPhase(GamePhase.countdown);
    _lastCountdownValue = countdownValue;
    feedback.countdownTick();
  }

  void _tickCountdown() {
    final value = countdownValue;
    if (value != _lastCountdownValue) {
      _lastCountdownValue = value;
      if (value > 0) feedback.countdownTick();
    }
    if (value == 0) _setPhase(GamePhase.playing);
  }

  void _tickClock(double dt) {
    final levelChange = timer.tick(dt);
    timerSeconds.value = timer.displaySeconds;
    if (levelChange == TimerLevel.warning ||
        levelChange == TimerLevel.critical) {
      feedback.timerWarning();
    }
    // At zero the game stops immediately, even mid-stroke.
    if (timer.isExpired) _endGame(GameEndTrigger.timer);
  }

  /// Pauses or resumes the whole simulation.
  void setPaused(bool paused) {
    if (phase.value == GamePhase.gameOver) return;
    _paused = paused;
    if (paused) {
      for (final p in players) {
        agentFor(p).reset();
      }
    }
    frame.ping();
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
      final agent = agentFor(attacker);
      var choice = agent.chooseBalloon(available, _phaseTime);
      aimingAt.value = choice ?? agent.aimHint;
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
    aimingAt.value = null;
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
    _setPhase(GamePhase.nextRound);
  }

  // ------------------------------------------------------------- Game end

  GameEndTrigger? _endTrigger;
  GameEndTrigger? get endTrigger => _endTrigger;

  void _endGame(GameEndTrigger trigger) {
    _endTrigger = trigger;
    for (final p in players) {
      agentFor(p).reset();
      // A run cut off by the end of the game still counts its distance.
      if (p.runStatus == RunStatus.running) {
        scoring.closeRun(p, bank: config.bankInterruptedRunScore);
        p.runStatus = RunStatus.halted;
      }
    }
    final bottomLine = _resultLine(bottom);
    final topLine = _resultLine(top);
    final outcome = resolveWinner(
      bottom: bottomLine,
      top: topLine,
      trigger: trigger,
    );
    result.value = GameResult(
      bottom: bottomLine,
      top: topLine,
      outcome: outcome,
      trigger: trigger,
      rounds: round.value,
    );
    final localWon = outcome.winner == 0;
    feedback.gameOver(localWon: localWon);
    if (outcome.winner != null) {
      final winner = outcome.winner == 0 ? bottom : top;
      effects.burst(
        winner.position,
        winner.identity.color,
        maxRadius: 160,
        duration: 1.2,
      );
    }
    _setPhase(GamePhase.gameOver);
  }

  ResultLine _resultLine(Player p) => ResultLine(
    name: p.identity.name,
    color: p.identity.color,
    isBot: p.identity.isBot,
    balloonsDestroyed: p.stats.balloonsDestroyed,
    balloonsStanding: p.balloonsStanding,
    score: p.stats.bankedScore,
    distance: p.stats.totalDistance.round(),
    penalties: p.stats.totalPenalties,
    successfulRuns: p.stats.successfulRuns,
    failedRuns: p.stats.failedRuns,
  );

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
    aimingAt.dispose();
    timerSeconds.dispose();
    result.dispose();
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
