import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';

/// Chunky paper-cut button that squashes when pressed.
class InkButton extends StatefulWidget {
  const InkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
    this.color,
    this.expand = true,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool primary;
  final Color? color;
  final bool expand;

  @override
  State<InkButton> createState() => _InkButtonState();
}

class _InkButtonState extends State<InkButton> {
  bool _down = false;

  void _setDown(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final accent = widget.color ?? AppColors.ink;
    final bg = widget.primary ? accent : AppColors.card;
    final fg = widget.primary ? AppColors.paper : accent;
    const depth = 5.0;

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, color: fg, size: 22),
          const SizedBox(width: 10),
        ],
        Text(
          widget.label,
          style: TextStyle(
            color: fg,
            fontSize: widget.primary ? 19 : 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => _setDown(true) : null,
        onTapCancel: () => _setDown(false),
        onTapUp: enabled
            ? (_) {
                _setDown(false);
                HapticFeedback.selectionClick();
                widget.onPressed!();
              }
            : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: enabled ? 1 : 0.5,
          child: SizedBox(
            height: (widget.primary ? 62 : 54) + depth,
            child: Stack(
              children: [
                // The "paper underneath" that gives the button its depth.
                Positioned.fill(
                  top: depth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 80),
                  curve: Curves.easeOut,
                  left: 0,
                  right: 0,
                  top: _down ? depth : 0,
                  bottom: _down ? 0 : depth,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.ink, width: 2.2),
                    ),
                    child: content,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
