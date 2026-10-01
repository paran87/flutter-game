import 'package:flutter/material.dart';

import '../controllers/game_controller.dart';
import '../controllers/player_agent.dart';
import '../models/game_state.dart';
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
import 'targeting_overlay.dart';

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
            // Dims the field (between the two goal lines) during attacks.
            Positioned(
              left: transform.boardRect.left,
              width: transform.boardRect.width,
              top: transform
                  .toScreen(Offset(0, controller.config.bottomGoalY))
                  .dy,
              bottom:
                  constraints.maxHeight -
                  transform.toScreen(Offset(0, controller.config.topGoalY)).dy,
              child: TargetingScrim(controller: controller),
            ),
            for (final player in controller.players)
              _BalloonRow(
                controller: controller,
                player: player,
                transform: transform,
                touchAgent: touchAgent,
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
///
/// During targeting the defender's row grows (bigger tap targets) and, when
/// the local human is attacking, each living balloon becomes tappable.
class _BalloonRow extends StatelessWidget {
  const _BalloonRow({
    required this.controller,
    required this.player,
    required this.transform,
    this.touchAgent,
  });

  final GameController controller;
  final Player player;
  final BoardTransform transform;
  final TouchPlayerAgent? touchAgent;

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
      child: ListenableBuilder(
        listenable: Listenable.merge([
          controller.balloonVersion,
          controller.phase,
          controller.aimingAt,
        ]),
        builder: (context, _) {
          final phase = controller.phase.value;
          final attacker = controller.roundWinner;
          final underAttack =
              attacker != null &&
              !identical(attacker, player) &&
              (phase == GamePhase.targeting ||
                  phase == GamePhase.balloonDestroyed);
          final canTap =
              underAttack &&
              phase == GamePhase.targeting &&
              controller.targetIndex == null &&
              !attacker.identity.isBot &&
              touchAgent != null;

          return AnimatedScale(
            scale: underAttack ? 1.3 : 1,
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutBack,
            alignment: player.isTop
                ? Alignment.topCenter
                : Alignment.bottomCenter,
            child: Stack(
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
                      targetable: canTap && balloon.isAlive,
                      aimed:
                          underAttack &&
                          attacker.identity.isBot &&
                          controller.targetIndex == null &&
                          controller.aimingAt.value == balloon.index,
                      attackerColor: attacker?.identity.color,
                      onTap: () => touchAgent?.selectBalloon(balloon.index),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
