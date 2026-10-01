import 'package:flutter/material.dart';

import '../controllers/game_controller.dart';
import '../models/game_state.dart';
import '../rendering/board_transform.dart';
import 'failure_toast.dart';
import 'phase_banner.dart';
import 'run_summary_card.dart';
import 'targeting_overlay.dart';

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
          child: Center(child: TargetingBanner(controller: controller)),
        ),
        Positioned.fromRect(
          rect: rect,
          child: Center(child: PhaseBanner(controller: controller)),
        ),
        Positioned.fromRect(
          rect: rect,
          child: IgnorePointer(
            child: ValueListenableBuilder<GamePhase>(
              valueListenable: controller.phase,
              builder: (context, phase, _) {
                final success = controller.lastSuccess.value;
                final show =
                    phase == GamePhase.playerSuccess && success != null;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: show
                      ? Center(
                          key: ValueKey(controller.round.value),
                          child: RunSummaryCard(
                            player: success.player,
                            summary: success.summary,
                          ),
                        )
                      : const SizedBox.shrink(),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
