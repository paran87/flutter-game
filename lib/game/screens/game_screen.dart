import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../models/game_config.dart';
import '../models/player.dart';
import '../models/player_identities.dart';
import '../rendering/board_transform.dart';
import '../rendering/paper_painter.dart';
import '../widgets/game_board.dart';
import '../widgets/scoreboard.dart';
import '../widgets/timer_widget.dart';

/// Phase 1: complete gameplay layout driven by static mock data.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const config = GameConfig();

  late final Player _human = Player(
    side: PlayerSide.bottom,
    identity: humanIdentity,
    startPosition: config.bottomStart,
    balloons: config.balloonsPerPlayer,
    maxAttempts: config.attemptsPerPlayer,
  );
  late final Player _bot = Player(
    side: PlayerSide.top,
    identity: botIdentity(config.botDifficulty),
    startPosition: config.topStart,
    balloons: config.balloonsPerPlayer,
    maxAttempts: config.attemptsPerPlayer,
  );

  @override
  void initState() {
    super.initState();
    // Mock data so every HUD element has something to show.
    _human
      ..stats.bankedScore = 610
      ..stats.totalDistance = 840
      ..attemptsRemaining = 3
      ..mockPop(2);
    _human.publishHud(liveScore: 610, inkFraction: 0.82);
    _bot
      ..stats.bankedScore = 520
      ..stats.totalDistance = 720
      ..attemptsRemaining = 2
      ..mockPop(0);
    _bot.publishHud(liveScore: 520, inkFraction: 0.64);
  }

  @override
  void dispose() {
    _human.dispose();
    _bot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: RepaintBoundary(child: CustomPaint(painter: PaperPainter())),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: PlayerScoreCard(player: _bot)),
                      const SizedBox(width: 6),
                      const Column(
                        children: [
                          TimerWidget(
                            seconds: 105,
                            warningSeconds: 30,
                            criticalSeconds: 10,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'ROUND 2',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: AppColors.inkFaint,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: PlayerScoreCard(player: _human)),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: GameBoard(
                      config: config,
                      bottom: _human,
                      top: _bot,
                      onTransform: (BoardTransform _) {},
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
