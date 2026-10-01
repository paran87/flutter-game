import 'package:flutter/material.dart';

import '../controllers/game_controller.dart';
import '../rendering/board_transform.dart';
import 'failure_toast.dart';
import 'phase_banner.dart';

/// Phase-driven overlays drawn on top of the board.
class BoardOverlays extends StatelessWidget {
  const BoardOverlays({
    super.key,
    required this.controller,
    required this.transform,
  });

  final GameController controller;
  final BoardTransform transform;

  @override
  Widget build(BuildContext context) {
    final config = controller.config;
    final rect = transform.boardRect;
    double screenY(double worldY) => transform.toScreen(Offset(0, worldY)).dy;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Failure toasts appear on the failing player's half of the board.
        Positioned(
          left: rect.left,
          width: rect.width,
          top: screenY(config.fieldRect.top + 40),
          child: Center(
            child: FailureToast(controller: controller, forTopPlayer: true),
          ),
        ),
        Positioned(
          left: rect.left,
          width: rect.width,
          top: screenY(config.fieldRect.bottom - 120),
          child: Center(
            child: FailureToast(controller: controller, forTopPlayer: false),
          ),
        ),
        Positioned.fromRect(
          rect: rect,
          child: Center(child: PhaseBanner(controller: controller)),
        ),
      ],
    );
  }
}
