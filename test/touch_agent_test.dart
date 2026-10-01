import 'package:dotline_duel/game/controllers/player_agent.dart';
import 'package:dotline_duel/game/models/game_config.dart';
import 'package:dotline_duel/game/models/obstacle_dot.dart';
import 'package:dotline_duel/game/models/player.dart';
import 'package:dotline_duel/game/models/player_identities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const config = GameConfig();
  Player player(PlayerSide side) => Player(
    side: side,
    identity: humanIdentity,
    startPosition: config.bottomStart,
    balloons: 3,
    maxAttempts: 3,
  );
  final context = AgentContext(
    config: config,
    field: ObstacleField.empty(config.fieldRect),
    self: player(PlayerSide.bottom),
    opponent: player(PlayerSide.top),
  );

  test('a finger held through a respawn is ignored until lifted', () {
    final agent = TouchPlayerAgent(maxSpeed: 500)
      ..pointerDown(1, const Offset(500, 100), const Offset(500, 180));
    expect(agent.update(1 / 60, context).target, const Offset(500, 100));

    // The pen respawns at its start while the finger is up by the balloons.
    agent.onRunStart(context);
    expect(agent.awaitingRelease, isTrue);
    agent.pointerMove(1, const Offset(400, 90), const Offset(400, 170));
    final held = agent.update(1 / 60, context);
    expect(held.target, isNull, reason: 'no streak back across the board');
    expect(held.penDown, isFalse);

    agent.pointerUp(1);
    expect(agent.awaitingRelease, isFalse);
    agent.pointerDown(2, const Offset(500, 1380), const Offset(500, 1460));
    expect(agent.update(1 / 60, context).target, const Offset(500, 1380));
  });

  test('a fresh run with no finger down needs no release', () {
    final agent = TouchPlayerAgent(maxSpeed: 500)..onRunStart(context);
    expect(agent.awaitingRelease, isFalse);
  });

  test('balloon centres sit in the balloon rows beyond each goal line', () {
    final top = config.balloonCenter(topOwner: true, index: 1, count: 3);
    final bottom = config.balloonCenter(topOwner: false, index: 0, count: 3);
    expect(top.dy, lessThan(config.bottomGoalY));
    expect(bottom.dy, greaterThan(config.topGoalY));
    expect(top.dx, 500);
    expect(bottom.dx, 250);
  });
}
