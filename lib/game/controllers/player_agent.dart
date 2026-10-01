import 'dart:ui';

import '../models/game_config.dart';
import '../models/obstacle_dot.dart';
import '../models/player.dart';

/// What an agent wants its pen to do this frame.
class AgentIntent {
  const AgentIntent({this.target, this.penDown = false});

  static const idle = AgentIntent();

  /// Desired pen position in world coordinates, or null for "stay put".
  final Offset? target;

  /// Whether the pen is touching the paper (finger down / bot drawing).
  final bool penDown;
}

/// Read-only view of the game handed to agents each frame.
class AgentContext {
  const AgentContext({
    required this.config,
    required this.field,
    required this.self,
    required this.opponent,
  });

  final GameConfig config;
  final ObstacleField field;
  final Player self;
  final Player opponent;

  /// The y coordinate this agent must cross before it can pop a balloon.
  double get goalY => self.isTop ? config.topGoalY : config.bottomGoalY;

  /// World position of one of the opponent's balloons.
  Offset opponentBalloon(int index) => config.balloonCenter(
    topOwner: opponent.isTop,
    index: index,
    count: opponent.balloons.length,
  );
}

/// Anything that can control a player: the local human, the bot, or —
/// later — a remote player whose input arrives over the network.
///
/// Agents never move the pen themselves. They only express intent, and the
/// GameController applies the same movement, collision and scoring rules to
/// every player.
abstract class PlayerAgent {
  /// Speed cap for this agent's pen (world units / s).
  double get maxSpeed;

  /// A new run is starting from the player's start position.
  void onRunStart(AgentContext context) {}

  /// Called every frame while the player may move.
  AgentIntent update(double dt, AgentContext context);

  /// A planned route to visualise in debug mode (empty if none).
  List<Offset> get debugPath => const [];

  /// Clears transient input (e.g. a held finger) between phases.
  void reset() {}

  void dispose() {}
}

/// The local human, driven by touch events forwarded from the game screen.
///
/// The screen converts the finger position into a world-space *target* that
/// already includes the finger offset, so the pen is never hidden under the
/// finger.
class TouchPlayerAgent extends PlayerAgent {
  TouchPlayerAgent({required this.maxSpeed});

  @override
  final double maxSpeed;

  int? _pointer;
  Offset? _target;
  Offset? _finger;

  /// After a respawn the finger is usually far from the start pad (e.g. up
  /// by the balloons). Its input is ignored until it is lifted and placed
  /// again, so the pen never streaks across the board on its own.
  bool _awaitingRelease = false;

  bool get isTouching => _pointer != null;

  /// True while the player must lift their finger before drawing again.
  bool get awaitingRelease => _awaitingRelease;

  /// Where the finger actually is (world coordinates), for the tether hint.
  Offset? get finger => _awaitingRelease ? null : _finger;

  /// Where the finger wants the pen to be (finger + offset).
  Offset? get target => _awaitingRelease ? null : _target;

  void pointerDown(int pointer, Offset worldTarget, Offset worldFinger) {
    // Only the first finger draws; extra fingers are ignored.
    if (_pointer != null) return;
    _pointer = pointer;
    _target = worldTarget;
    _finger = worldFinger;
  }

  void pointerMove(int pointer, Offset worldTarget, Offset worldFinger) {
    if (pointer != _pointer) return;
    _target = worldTarget;
    _finger = worldFinger;
  }

  void pointerUp(int pointer) {
    if (pointer != _pointer) return;
    _pointer = null;
    _target = null;
    _finger = null;
    _awaitingRelease = false;
  }

  @override
  void onRunStart(AgentContext context) {
    if (_pointer != null) _awaitingRelease = true;
  }

  @override
  AgentIntent update(double dt, AgentContext context) => _awaitingRelease
      ? AgentIntent.idle
      : AgentIntent(target: _target, penDown: _pointer != null);
}

/// An agent that never moves. Useful as a placeholder and in tests.
class IdleAgent extends PlayerAgent {
  IdleAgent({this.maxSpeed = 0});

  @override
  final double maxSpeed;

  @override
  AgentIntent update(double dt, AgentContext context) => AgentIntent.idle;
}
