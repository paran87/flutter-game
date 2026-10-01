import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../app/theme.dart';
import '../controllers/game_controller.dart';
import '../controllers/player_agent.dart';
import '../models/game_config.dart';
import '../rendering/board_transform.dart';
import '../rendering/paper_painter.dart';
import '../services/game_feedback.dart';
import '../widgets/game_board.dart';
import '../widgets/scoreboard.dart';
import '../widgets/status_bar.dart';
import '../widgets/timer_widget.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.config = const GameConfig()});

  final GameConfig config;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final TouchPlayerAgent _human = TouchPlayerAgent(
    maxSpeed: widget.config.playerSpeed,
  );
  late final GameController _controller = GameController(
    config: widget.config,
    bottomAgent: _human,
    topAgent: IdleAgent(),
    feedback: GameFeedback(),
  );
  late final Ticker _ticker = createTicker(_onTick);
  final GlobalKey _boardKey = GlobalKey();
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

  // ------------------------------------------------------------ Touch input

  /// Finger offset in logical pixels, scaled gently with the screen so it
  /// feels the same on small and large phones.
  double get _touchOffset {
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    return widget.config.touchOffset * (shortest / 400).clamp(0.85, 1.3);
  }

  /// Converts a global finger position into (target, finger) world points.
  (Offset, Offset)? _toWorld(Offset globalPosition) {
    final transform = _transform;
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (transform == null || box == null || !box.hasSize) return null;
    final local = box.globalToLocal(globalPosition);
    // The pen sits *above* the finger so the finger never covers it.
    final target = transform.toWorld(local - Offset(0, _touchOffset));
    return (target, transform.toWorld(local));
  }

  void _onPointerDown(PointerDownEvent e) {
    final world = _toWorld(e.position);
    if (world != null) _human.pointerDown(e.pointer, world.$1, world.$2);
  }

  void _onPointerMove(PointerMoveEvent e) {
    final world = _toWorld(e.position);
    if (world != null) _human.pointerMove(e.pointer, world.$1, world.$2);
  }

  void _onPointerUp(PointerEvent e) => _human.pointerUp(e.pointer);

  @override
  void dispose() {
    _ticker.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerUp,
        child: Stack(
          children: [
            const Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(painter: PaperPainter()),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _TopBar(controller: _controller),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: SizedBox.expand(
                        key: _boardKey,
                        child: GameBoard(
                          controller: _controller,
                          touchAgent: _human,
                          onTransform: (t) => _transform = t,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: Center(
                      child: StatusBar(
                        controller: _controller,
                        player: _controller.bottom,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
