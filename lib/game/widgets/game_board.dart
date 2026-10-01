import 'package:flutter/material.dart';

import '../controllers/game_controller.dart';
import '../controllers/player_agent.dart';
import '../models/obstacle_dot.dart';
import '../models/player.dart';
import '../rendering/board_decor_painter.dart';
import '../rendering/board_transform.dart';
import '../rendering/debug_painter.dart';
import '../rendering/game_board_painter.dart';
import '../rendering/obstacle_painter.dart';
import '../rendering/effects_painter.dart';
import '../rendering/trace_painter.dart';
import 'balloon_widget.dart';
import 'board_overlays.dart';
import 'debug_panel.dart';

/// The playing surface: decor, dots, traces, markers and balloons.
///
/// Layers are split by how often they change:
///   * decor and obstacles — cached behind RepaintBoundaries,
///   * traces/markers/effects — one CustomPainter repainted per frame,
///   * balloons — widgets, rebuilt only when balloon state changes.
class GameBoard extends StatefulWidget {
  const GameBoard({
    super.key,
    required this.controller,
    required this.onTransform,
    this.touchAgent,
    this.debug = false,
  });

  final GameController controller;

  /// The local human's input, used to draw the finger tether.
  final TouchPlayerAgent? touchAgent;

  /// Shows the debug geometry and live stats panel.
  final bool debug;

  /// Reports the current world→screen mapping (needed for touch input).
  final ValueChanged<BoardTransform> onTransform;

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  /// Lives as long as the board so cached trace geometry survives rebuilds.
  late final TraceRenderer _traces = TraceRenderer(widget.controller.config);
  final EffectsPainter _effects = EffectsPainter();
  final DebugPainter _debug = DebugPainter();

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final touchAgent = widget.touchAgent;
    return LayoutBuilder(
      builder: (context, constraints) {
        final transform = BoardTransform.fit(
          constraints.biggest,
          controller.config,
        );
        widget.onTransform(transform);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: BoardDecorPainter(
                    config: controller.config,
                    transform: transform,
                    topColor: controller.top.identity.color,
                    bottomColor: controller.bottom.identity.color,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: RepaintBoundary(
                child: ValueListenableBuilder<ObstacleField>(
                  valueListenable: controller.field,
                  builder: (context, field, _) => CustomPaint(
                    painter: ObstaclePainter(
                      field: field,
                      transform: transform,
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: GameBoardPainter(
                    controller: controller,
                    transform: transform,
                    traces: _traces,
                    effects: _effects,
                    debug: widget.debug ? _debug : null,
                    touchAgent: touchAgent,
                  ),
                ),
              ),
            ),
            for (final player in controller.players)
              _BalloonRow(
                controller: controller,
                player: player,
                transform: transform,
              ),
            Positioned.fill(
              child: BoardOverlays(
                controller: controller,
                transform: transform,
              ),
            ),
            if (widget.debug)
              Positioned(
                left: transform.boardRect.left + 4,
                top: transform.boardRect.top + 4,
                child: DebugPanel(controller: controller),
              ),
          ],
        );
      },
    );
  }
}

/// One player's balloons, positioned in world space at their end of the board.
///
/// Balloons are popped by steering a pen into them, so they take no taps.
/// While the opponent is hunting (has crossed the line) a reticle in the
/// opponent's colour marks the balloons that are now in danger.
class _BalloonRow extends StatelessWidget {
  const _BalloonRow({
    required this.controller,
    required this.player,
    required this.transform,
  });

  final GameController controller;
  final Player player;
  final BoardTransform transform;

  @override
  Widget build(BuildContext context) {
    final config = controller.config;
    final attacker = controller.opponentOf(player);
    final width = 92 * transform.scale;
    final height = width * 1.45;
    // The painter draws the balloon body centred 36% down its box.
    const bodyCenter = 0.36;

    return Positioned.fill(
      child: IgnorePointer(
        child: ListenableBuilder(
          listenable: Listenable.merge([
            controller.balloonVersion,
            attacker.hunting,
          ]),
          builder: (context, _) {
            final hunted = attacker.hunting.value;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (final balloon in player.balloons)
                  Builder(
                    builder: (context) {
                      final center = transform.toScreen(
                        controller.balloonCenter(player, balloon.index),
                      );
                      return Positioned(
                        left: center.dx - width / 2,
                        top: center.dy - height * bodyCenter,
                        child: BalloonWidget(
                          color: player.identity.color,
                          status: balloon.status,
                          width: width,
                          index: balloon.index,
                          popDuration: config.balloonAnimationDuration,
                          aimed: hunted && balloon.isAlive,
                          attackerColor: attacker.identity.color,
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
