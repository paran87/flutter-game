import 'package:flutter/material.dart';

import '../controllers/game_controller.dart';
import '../controllers/player_agent.dart';
import '../models/obstacle_dot.dart';
import '../models/player.dart';
import '../rendering/board_decor_painter.dart';
import '../rendering/board_transform.dart';
import '../rendering/game_board_painter.dart';
import '../rendering/obstacle_painter.dart';
import '../rendering/effects_painter.dart';
import '../rendering/trace_painter.dart';
import 'balloon_widget.dart';
import 'board_overlays.dart';

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
  });

  final GameController controller;

  /// The local human's input, used to draw the finger tether.
  final TouchPlayerAgent? touchAgent;

  /// Reports the current world→screen mapping (needed for touch input).
  final ValueChanged<BoardTransform> onTransform;

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  /// Lives as long as the board so cached trace geometry survives rebuilds.
  late final TraceRenderer _traces = TraceRenderer(widget.controller.config);
  final EffectsPainter _effects = EffectsPainter();

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
          ],
        );
      },
    );
  }
}

/// One player's balloons, positioned in world space at their end of the board.
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
    final xs = config.balloonXs(player.balloons.length);
    final y = player.isTop ? config.topBalloonY : config.bottomBalloonY;
    final width = 92 * transform.scale;
    final height = width * 1.45;
    final left = transform.toScreen(Offset(xs.first, y)).dx - width / 2;
    final right = transform.toScreen(Offset(xs.last, y)).dx + width / 2;
    final top = transform.toScreen(Offset(0, y)).dy - height * 0.4;

    return Positioned(
      left: left,
      top: top,
      width: right - left,
      height: height,
      child: ValueListenableBuilder<PlayerHudSnapshot>(
        valueListenable: player.hud,
        builder: (context, _, _) => Stack(
          clipBehavior: Clip.none,
          children: [
            for (final balloon in player.balloons)
              Positioned(
                left:
                    transform.toScreen(Offset(xs[balloon.index], y)).dx -
                    width / 2 -
                    left,
                top: 0,
                child: BalloonWidget(
                  color: player.identity.color,
                  status: balloon.status,
                  width: width,
                  index: balloon.index,
                  popDuration: config.balloonAnimationDuration,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
