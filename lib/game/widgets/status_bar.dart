import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../controllers/game_controller.dart';
import '../models/game_state.dart';
import '../models/player.dart';

/// One-line contextual hint for the local player, under the board.
///
/// Listens to the frame signal but only rebuilds when the message changes.
class StatusBar extends StatefulWidget {
  const StatusBar({super.key, required this.controller, required this.player});

  final GameController controller;
  final Player player;

  @override
  State<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends State<StatusBar> {
  _Hint _hint = const _Hint('', AppColors.inkFaint);

  @override
  void initState() {
    super.initState();
    widget.controller.frame.addListener(_update);
    _update();
  }

  @override
  void dispose() {
    widget.controller.frame.removeListener(_update);
    super.dispose();
  }

  void _update() {
    final next = _compute();
    if (next != _hint) setState(() => _hint = next);
  }

  _Hint _compute() {
    final c = widget.controller;
    final p = widget.player;
    if (c.phase.value != GamePhase.playing) {
      return const _Hint('', AppColors.inkFaint);
    }
    switch (p.runStatus) {
      case RunStatus.ready:
        return const _Hint(
          'Drag below your pen to start drawing',
          AppColors.inkSoft,
          Icons.touch_app_rounded,
        );
      case RunStatus.failed:
        return _Hint(
          p.failureReason?.description ?? '',
          AppColors.danger,
          Icons.error_outline_rounded,
        );
      case RunStatus.eliminated:
        return const _Hint(
          'Out of attempts — the bot races on',
          AppColors.inkFaint,
          Icons.block_rounded,
        );
      case RunStatus.running:
        if (p.penLiftedFor > 0) {
          return const _Hint(
            'Pen lifted! Touch again to keep drawing',
            AppColors.danger,
            Icons.warning_amber_rounded,
          );
        }
        if (c.inkFraction(p) < 0.25) {
          return const _Hint(
            'Ink running low — head for the line!',
            AppColors.warning,
            Icons.water_drop_outlined,
          );
        }
        return const _Hint(
          'Reach the dashed line on the far side',
          AppColors.inkFaint,
          Icons.flag_outlined,
        );
      case RunStatus.finished:
      case RunStatus.halted:
        return const _Hint('', AppColors.inkFaint);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: _hint.text.isEmpty
          ? const SizedBox.shrink()
          : Row(
              key: ValueKey(_hint.text),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_hint.icon != null) ...[
                  Icon(_hint.icon, size: 16, color: _hint.color),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    _hint.text,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _hint.color,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

@immutable
class _Hint {
  const _Hint(this.text, this.color, [this.icon]);

  final String text;
  final Color color;
  final IconData? icon;

  @override
  bool operator ==(Object other) =>
      other is _Hint && other.text == text && other.color == color;

  @override
  int get hashCode => Object.hash(text, color);
}
