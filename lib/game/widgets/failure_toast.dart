import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../controllers/game_controller.dart';
import '../models/game_state.dart';

/// Pops a short "OUT OF INK! −1 ♥" pill when a player's run fails.
class FailureToast extends StatefulWidget {
  const FailureToast({
    super.key,
    required this.controller,
    required this.forTopPlayer,
  });

  final GameController controller;

  /// Which player's failures this toast reports.
  final bool forTopPlayer;

  @override
  State<FailureToast> createState() => _FailureToastState();
}

class _FailureToastState extends State<FailureToast> {
  RunFailure? _shown;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    widget.controller.lastFailure.addListener(_onFailure);
  }

  void _onFailure() {
    final failure = widget.controller.lastFailure.value;
    if (failure == null || failure.player.isTop != widget.forTopPlayer) return;
    setState(() => _shown = failure);
    _hide?.cancel();
    _hide = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _shown = null);
    });
  }

  @override
  void dispose() {
    widget.controller.lastFailure.removeListener(_onFailure);
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final failure = _shown;
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: failure == null
            ? const SizedBox.shrink()
            : _Pill(
                key: ValueKey(failure.serial),
                title: failure.reason.title,
                name: failure.player.identity.name,
                attemptsLeft: failure.player.attemptsRemaining,
              ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.title,
    required this.name,
    required this.attemptsLeft,
  });

  final String title;
  final String name;
  final int attemptsLeft;

  @override
  Widget build(BuildContext context) {
    final detail = attemptsLeft == 0
        ? 'no attempts left'
        : '-1 attempt · $attemptsLeft left';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.ink, width: 2),
        boxShadow: const [
          BoxShadow(color: AppColors.ink, offset: Offset(0, 3)),
        ],
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$name  ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: title,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            TextSpan(
              text: '  $detail',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
