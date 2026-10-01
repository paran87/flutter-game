import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../app/theme.dart';
import '../controllers/game_controller.dart';
import '../rendering/board_transform.dart';
import '../rendering/paper_painter.dart';
import '../widgets/game_board.dart';
import '../widgets/scoreboard.dart';
import '../widgets/timer_widget.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final GameController _controller = GameController();
  late final Ticker _ticker = createTicker(_onTick);
  Duration _lastTick = Duration.zero;
  BoardTransform? _transform;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    // Clamp dt so a dropped frame or a resumed app can't teleport anything.
    final dt = ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 1 / 20);
    _lastTick = elapsed;
    _controller.tick(dt);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _controller.dispose();
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
                _TopBar(controller: _controller),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: GameBoard(
                      controller: _controller,
                      onTransform: (t) => _transform = t,
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

class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final config = controller.config;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: PlayerScoreCard(player: controller.top)),
          const SizedBox(width: 6),
          Column(
            children: [
              TimerWidget(
                seconds: config.gameDuration.inSeconds,
                warningSeconds: config.timerWarningSeconds,
                criticalSeconds: config.timerCriticalSeconds,
              ),
              const SizedBox(height: 4),
              ValueListenableBuilder<int>(
                valueListenable: controller.round,
                builder: (context, round, _) => Text(
                  'ROUND $round',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: AppColors.inkFaint,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
          Expanded(child: PlayerScoreCard(player: controller.bottom)),
        ],
      ),
    );
  }
}
