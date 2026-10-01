import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../controllers/game_controller.dart';
import '../models/game_state.dart';

bool _isAttackPhase(GamePhase phase) =>
    phase == GamePhase.targeting || phase == GamePhase.balloonDestroyed;

/// Dims the dot field while someone is attacking so the balloons pop out.
class TargetingScrim extends StatelessWidget {
  const TargetingScrim({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ValueListenableBuilder<GamePhase>(
        valueListenable: controller.phase,
        builder: (context, phase, _) => AnimatedOpacity(
          opacity: _isAttackPhase(phase) ? 1 : 0,
          duration: const Duration(milliseconds: 350),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.paper.withValues(alpha: 0.72),
            ),
          ),
        ),
      ),
    );
  }
}

/// "ATTACK!" banner with instructions and the time left to choose.
class TargetingBanner extends StatelessWidget {
  const TargetingBanner({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ValueListenableBuilder<GamePhase>(
        valueListenable: controller.phase,
        builder: (context, phase, _) {
          final attacker = controller.roundWinner;
          final show = phase == GamePhase.targeting && attacker != null;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, a) => ScaleTransition(
              scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
              child: FadeTransition(opacity: a, child: child),
            ),
            child: !show
                ? const SizedBox.shrink()
                : _Banner(
                    key: ValueKey(controller.round.value),
                    controller: controller,
                    humanAttacking: !attacker.identity.isBot,
                    color: attacker.identity.color,
                  ),
          );
        },
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    super.key,
    required this.controller,
    required this.humanAttacking,
    required this.color,
  });

  final GameController controller;
  final bool humanAttacking;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final defender = controller.defender!;
    final title = humanAttacking ? 'ATTACK!' : 'INCOMING!';
    final subtitle = humanAttacking
        ? 'Tap a ${defender.identity.name} balloon to pop it'
        : '${controller.roundWinner!.identity.name} is aiming at your balloons';
    final limit = controller.config.targetingDuration.inMicroseconds / 1e6;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 46,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            color: color,
            shadows: const [Shadow(color: AppColors.ink, offset: Offset(0, 3))],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        if (humanAttacking) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: 160,
            height: 6,
            child: AnimatedBuilder(
              animation: controller.frame,
              builder: (context, _) {
                final left = controller.targetIndex != null
                    ? 0.0
                    : (1 - controller.phaseTime / limit).clamp(0.0, 1.0);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: left,
                    backgroundColor: AppColors.paperShade,
                    color: color,
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
