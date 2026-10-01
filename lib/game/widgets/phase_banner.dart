import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../controllers/game_controller.dart';
import '../models/game_state.dart';

/// "READY?", "3 · 2 · 1", "GO!", and the end-of-game splash.
///
/// Listens to the frame signal but only rebuilds when the label changes.
class PhaseBanner extends StatefulWidget {
  const PhaseBanner({super.key, required this.controller});

  final GameController controller;

  @override
  State<PhaseBanner> createState() => _PhaseBannerState();
}

class _PhaseBannerState extends State<PhaseBanner> {
  _Label? _label;

  GameController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.frame.addListener(_update);
    _update();
  }

  @override
  void dispose() {
    c.frame.removeListener(_update);
    super.dispose();
  }

  void _update() {
    final next = _compute();
    if (next != _label) setState(() => _label = next);
  }

  _Label? _compute() {
    switch (c.phase.value) {
      case GamePhase.intro:
        return const _Label(
          'READY?',
          AppColors.ink,
          sub: 'Cross the dots, then pop a balloon',
        );
      case GamePhase.countdown:
        return _Label('${c.countdownValue}', AppColors.ink, big: true);
      case GamePhase.playing:
        // Flash GO! for the first half second of the match.
        return c.phaseTime < 0.55
            ? const _Label('GO!', AppColors.success, big: true)
            : null;
      case GamePhase.gameOver:
        final result = c.result.value;
        if (result == null) return null;
        final winner = result.winnerLine;
        if (winner == null) {
          return const _Label(
            'DRAW',
            AppColors.inkSoft,
            sub: 'Nobody blinked.',
          );
        }
        return winner.isBot
            ? _Label('DEFEAT', AppColors.inkSoft, sub: result.trigger.headline)
            : _Label('VICTORY!', winner.color, sub: result.trigger.headline);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _label;
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        // Fast exit so consecutive countdown numbers never overlap.
        reverseDuration: const Duration(milliseconds: 90),
        switchInCurve: Curves.easeOutBack,
        transitionBuilder: (child, a) => ScaleTransition(
          scale: Tween(begin: 0.4, end: 1.0).animate(a),
          child: FadeTransition(opacity: a, child: child),
        ),
        child: label == null
            ? const SizedBox.shrink()
            : _BannerText(key: ValueKey(label.text), label: label),
      ),
    );
  }
}

class _BannerText extends StatelessWidget {
  const _BannerText({super.key, required this.label});

  final _Label label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.text,
          style: TextStyle(
            fontSize: label.big ? 96 : 52,
            fontWeight: FontWeight.w900,
            letterSpacing: label.big ? 0 : 4,
            height: 1,
            color: label.color,
            shadows: [
              Shadow(
                color: AppColors.paper.withValues(alpha: 0.9),
                blurRadius: 18,
              ),
              const Shadow(
                color: AppColors.paper,
                offset: Offset(0, 2),
                blurRadius: 2,
              ),
            ],
          ),
        ),
        if (label.sub != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.card.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              label.sub!,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.inkSoft,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

@immutable
class _Label {
  const _Label(this.text, this.color, {this.sub, this.big = false});

  final String text;
  final Color color;
  final String? sub;
  final bool big;

  @override
  bool operator ==(Object other) =>
      other is _Label && other.text == text && other.sub == sub;

  @override
  int get hashCode => Object.hash(text, sub);
}
