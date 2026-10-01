import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../app/app.dart';
import '../../app/theme.dart';
import '../controllers/bot_controller.dart';
import '../controllers/game_controller.dart';
import '../controllers/player_agent.dart';
import '../models/game_config.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../rendering/board_transform.dart';
import '../rendering/paper_painter.dart';
import '../services/game_feedback.dart';
import '../widgets/game_board.dart';
import '../widgets/pause_overlay.dart';
import '../widgets/scoreboard.dart';
import '../widgets/status_bar.dart';
import '../widgets/timer_widget.dart';
import 'result_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.config = const GameConfig()});

  final GameConfig config;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TouchPlayerAgent _human = TouchPlayerAgent(
    maxSpeed: widget.config.playerSpeed,
  );
  late final GameController _controller = GameController(
    config: widget.config,
    bottomAgent: _human,
    topAgent: BotController(difficulty: widget.config.botDifficulty),
    feedback: GameFeedback(),
  );
  late final Ticker _ticker = createTicker(_onTick);
  final GlobalKey _boardKey = GlobalKey();
  Duration _lastTick = Duration.zero;
  BoardTransform? _transform;
  bool _paused = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Never let the clock run while the app is in the background.
    if (state != AppLifecycleState.resumed) _setPaused(true);
  }

  void _onTick(Duration elapsed) {
    // Clamp dt so a dropped frame or a resumed app can't teleport anything.
    final dt = ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 1 / 20);
    _lastTick = elapsed;
    _controller.tick(dt);
    _maybeShowResult();
  }

  void _maybeShowResult() {
    final result = _controller.result.value;
    if (_leaving || result == null) return;
    final delay = widget.config.gameOverDelay.inMicroseconds / 1e6;
    if (_controller.phaseTime < delay) return;
    _leaving = true;
    Navigator.of(context).pushReplacement(
      inkRoute(ResultScreen(result: result, config: widget.config)),
    );
  }

  void _setPaused(bool paused) {
    if (_paused == paused || _controller.phase.value == GamePhase.gameOver) {
      return;
    }
    _controller.setPaused(paused);
    setState(() => _paused = paused);
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
    if (_paused) return;
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
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _setPaused(true);
      },
      child: Scaffold(
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
                    _TopBar(
                      controller: _controller,
                      onPause: () => _setPaused(true),
                    ),
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
              if (_paused)
                Positioned.fill(
                  child: PauseOverlay(
                    onResume: () => _setPaused(false),
                    onRestart: () => Navigator.of(context).pushReplacement(
                      inkRoute(GameScreen(config: widget.config)),
                    ),
                    onQuit: () => Navigator.of(context).pop(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller, required this.onPause});

  final GameController controller;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final config = controller.config;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: controller.phase,
              builder: (context, _) => PlayerScoreCard(
                player: controller.top,
                highlight: _attacking(controller.top),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Column(
            children: [
              ListenableBuilder(
                listenable: Listenable.merge([
                  controller.timerSeconds,
                  controller.phase,
                ]),
                builder: (context, _) => TimerWidget(
                  seconds: controller.timerSeconds.value,
                  warningSeconds: config.timerWarningSeconds,
                  criticalSeconds: config.timerCriticalSeconds,
                  running: controller.phase.value == GamePhase.playing,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  IconButton(
                    onPressed: onPause,
                    tooltip: 'Pause',
                    visualDensity: VisualDensity.compact,
                    iconSize: 20,
                    color: AppColors.inkSoft,
                    icon: const Icon(Icons.pause_circle_outline_rounded),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ListenableBuilder(
              listenable: controller.phase,
              builder: (context, _) => PlayerScoreCard(
                player: controller.bottom,
                highlight: _attacking(controller.bottom),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _attacking(Player player) {
    final phase = controller.phase.value;
    return identical(controller.roundWinner, player) &&
        (phase == GamePhase.playerSuccess ||
            phase == GamePhase.targeting ||
            phase == GamePhase.balloonDestroyed);
  }
}
