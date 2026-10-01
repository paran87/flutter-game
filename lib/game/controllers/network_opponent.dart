import 'dart:ui';

import 'player_agent.dart';

/// Drives the remote player's pen from position updates received over
/// Supabase Realtime. The GameController treats this exactly like the
/// BotController or TouchPlayerAgent — it only reads AgentIntent each frame.
///
/// The RoomService writes to [applyRemoteState] whenever a new position
/// arrives over the channel. Between updates the pen keeps its last known
/// position (penDown follows the last received state).
class NetworkOpponent extends PlayerAgent {
  NetworkOpponent({required this.maxSpeed});

  @override
  final double maxSpeed;

  Offset? _target;
  bool _penDown = false;

  /// Time since the last remote update arrived, in seconds.
  double _staleness = 0;

  /// After this many seconds without an update we treat the pen as lifted
  /// (the remote device is likely disconnected or lagging).
  static const _staleThreshold = 0.5;

  bool get isStale => _staleness > _staleThreshold;

  /// Called by RoomService when a position update arrives from the channel.
  ///
  /// [normalizedX] and [normalizedY] are 0.0–1.0 world-normalised coords.
  void applyRemoteState({
    required double normalizedX,
    required double normalizedY,
    required bool penDown,
    required double worldWidth,
    required double worldHeight,
  }) {
    _target = Offset(normalizedX * worldWidth, normalizedY * worldHeight);
    _penDown = penDown;
    _staleness = 0;
  }

  @override
  AgentIntent update(double dt, AgentContext context) {
    _staleness += dt;
    if (isStale) return AgentIntent.idle;
    return AgentIntent(target: _target, penDown: _penDown);
  }

  @override
  void reset() {
    _target = null;
    _penDown = false;
    _staleness = 0;
  }
}
