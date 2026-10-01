import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'ink_button.dart';

/// Paper sheet laid over the game while paused.
class PauseOverlay extends StatelessWidget {
  const PauseOverlay({
    super.key,
    required this.onResume,
    required this.onRestart,
    required this.onQuit,
  });

  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.ink.withValues(alpha: 0.35),
      child: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.ink, width: 2.5),
            boxShadow: const [
              BoxShadow(color: AppColors.ink, offset: Offset(0, 6)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('PAUSED', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                'The ink can wait.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              InkButton(
                label: 'RESUME',
                icon: Icons.play_arrow_rounded,
                primary: true,
                onPressed: onResume,
              ),
              const SizedBox(height: AppSpacing.md),
              InkButton(
                label: 'RESTART',
                icon: Icons.replay_rounded,
                onPressed: onRestart,
              ),
              const SizedBox(height: AppSpacing.md),
              InkButton(
                label: 'QUIT',
                icon: Icons.close_rounded,
                onPressed: onQuit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
