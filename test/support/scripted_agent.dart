import 'dart:ui';

import 'package:dotline_duel/game/controllers/player_agent.dart';

/// Test agent that steers toward a fixed waypoint list with the pen down
/// (unless [penDown] is switched off).
class ScriptedAgent extends PlayerAgent {
  ScriptedAgent({this.maxSpeed = 600, List<Offset>? waypoints})
    : waypoints = waypoints ?? [];

  @override
  final double maxSpeed;
  List<Offset> waypoints;
  bool penDown = true;
  int _index = 0;
  int runsStarted = 0;

  @override
  void onRunStart(AgentContext context) {
    _index = 0;
    runsStarted++;
  }

  @override
  AgentIntent update(double dt, AgentContext context) {
    if (!penDown) return const AgentIntent(penDown: false);
    if (waypoints.isEmpty) return const AgentIntent(penDown: true);
    final self = context.self.position;
    while (_index < waypoints.length - 1 &&
        (waypoints[_index] - self).distance < 6) {
      _index++;
    }
    return AgentIntent(target: waypoints[_index], penDown: true);
  }
}
