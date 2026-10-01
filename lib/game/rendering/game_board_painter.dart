import 'package:flutter/rendering.dart';

import '../controllers/game_controller.dart';
import '../models/player.dart';
import '../widgets/player_marker.dart';
import 'board_transform.dart';

/// Dynamic board layer, repainted every frame from [GameController.frame]
/// without rebuilding any widgets.
class GameBoardPainter extends CustomPainter {
  GameBoardPainter({required this.controller, required this.transform})
    : super(repaint: controller.frame);

  final GameController controller;
  final BoardTransform transform;

  @override
  void paint(Canvas canvas, Size size) {
    for (final player in controller.players) {
      _paintMarker(canvas, player);
    }
  }

  void _paintMarker(Canvas canvas, Player player) {
    PlayerMarkerPainter.paint(
      canvas,
      transform.toScreen(player.position),
      controller.config.playerRadius * transform.scale,
      player.identity.color,
      label: player.identity.name,
    );
  }

  @override
  bool shouldRepaint(GameBoardPainter old) =>
      old.controller != controller || old.transform != transform;
}
