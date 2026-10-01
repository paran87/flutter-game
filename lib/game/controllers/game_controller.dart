import 'dart:ui';

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/game_config.dart';
import '../models/game_state.dart';
import '../models/obstacle_dot.dart';
import '../models/player.dart';
import '../models/player_identities.dart';
import '../utils/obstacle_generator.dart';

/// Central game state machine. Owns players, the obstacle field, the clock
/// and round progression. Widgets only read from it and forward input.
class GameController {
  GameController({this.config = const GameConfig()})
    : _baseSeed = config.obstacleSeed ?? math.Random().nextInt(1 << 30) {
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
  }

  final GameConfig config;
  final int _baseSeed;

  late final Player bottom;
  late final Player top;
  List<Player> get players => [bottom, top];

  /// Fires every simulated frame; painters repaint from it.
  final FrameSignal frame = FrameSignal();

  /// Fires when a new obstacle field is generated.
  final ValueNotifier<ObstacleField> field = ValueNotifier(
    ObstacleField.empty(Rect.zero),
  );

  final ValueNotifier<GamePhase> phase = ValueNotifier(GamePhase.intro);
  final ValueNotifier<int> round = ValueNotifier(1);

  void _generateField() {
    // Each round gets its own layout, reproducible from the base seed.
    final seed = _baseSeed + (round.value - 1) * 7919;
    field.value = ObstacleGenerator(config).generate(seed);
  }

  /// Advances the simulation by [dt] seconds.
  void tick(double dt) {
    frame.ping();
  }

  void dispose() {
    frame.dispose();
    field.dispose();
    phase.dispose();
    round.dispose();
    for (final p in players) {
      p.dispose();
    }
  }
}

/// A listenable that is pinged once per simulated frame.
class FrameSignal extends ChangeNotifier {
  void ping() => notifyListeners();
}
