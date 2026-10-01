import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/balloon.dart';
import '../rendering/balloon_painter.dart';

/// A floating balloon that can be targeted and popped.
class BalloonWidget extends StatefulWidget {
  const BalloonWidget({
    super.key,
    required this.color,
    required this.status,
    required this.width,
    this.index = 0,
    this.targetable = false,
    this.attackerColor,
    this.onTap,
    this.popDuration = const Duration(milliseconds: 800),
  });

  final Color color;
  final BalloonStatus status;
  final double width;
  final int index;

  /// Shows a pulsing crosshair and accepts taps.
  final bool targetable;
  final Color? attackerColor;
  final VoidCallback? onTap;
  final Duration popDuration;

  double get height => width * 1.45;

  @override
  State<BalloonWidget> createState() => _BalloonWidgetState();
}

class _BalloonWidgetState extends State<BalloonWidget>
    with TickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 2300 + widget.index * 270),
  )..repeat();

  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: widget.popDuration,
  );

  late final AnimationController _target = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _syncStatus(null);
    if (widget.targetable) _target.repeat();
  }

  @override
  void didUpdateWidget(BalloonWidget old) {
    super.didUpdateWidget(old);
    if (old.status != widget.status) _syncStatus(old.status);
    if (old.targetable != widget.targetable) {
      widget.targetable ? _target.repeat() : _target.stop();
    }
  }

  void _syncStatus(BalloonStatus? previous) {
    switch (widget.status) {
      case BalloonStatus.popping:
        _pop.forward(from: 0);
      case BalloonStatus.destroyed:
        // Keep showing the burst if we arrive here mid-animation.
        if (previous != BalloonStatus.popping) _pop.value = 1;
      case BalloonStatus.intact:
      case BalloonStatus.targeted:
        _pop.value = 0;
    }
  }

  @override
  void dispose() {
    _float.dispose();
    _pop.dispose();
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = Size(widget.width, widget.height);
    final isTargeted = widget.status == BalloonStatus.targeted;
    final destroyed = widget.status == BalloonStatus.destroyed;

    Widget balloon = AnimatedBuilder(
      animation: Listenable.merge([_float, _pop]),
      builder: (context, _) {
        final phase = _float.value * math.pi * 2;
        final still = destroyed || _pop.value > 0;
        final bob = still ? 0.0 : math.sin(phase) * widget.width * 0.06;
        final sway = still ? 0.0 : math.sin(phase + 1.3) * 0.05;
        final popDone = _pop.isCompleted && destroyed;
        return Transform.translate(
          offset: Offset(0, bob),
          child: Transform.rotate(
            angle: sway,
            alignment: Alignment.bottomCenter,
            child: CustomPaint(
              size: size,
              painter: BalloonPainter(
                color: widget.color,
                popProgress: _pop.value,
                destroyed: popDone || (destroyed && !_pop.isAnimating),
                seed: widget.index * 31 + 7,
              ),
            ),
          ),
        );
      },
    );

    if (widget.targetable || isTargeted) {
      balloon = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          balloon,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _target,
                builder: (context, _) => CustomPaint(
                  painter: _CrosshairPainter(
                    color: widget.attackerColor ?? Colors.black,
                    pulse: _target.value,
                    locked: isTargeted,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Semantics(
      button: widget.targetable,
      label: destroyed ? 'Destroyed balloon' : 'Balloon ${widget.index + 1}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.targetable ? widget.onTap : null,
        child: SizedBox.fromSize(size: size, child: balloon),
      ),
    );
  }
}

/// Rotating dashed reticle drawn around a targetable balloon.
class _CrosshairPainter extends CustomPainter {
  _CrosshairPainter({
    required this.color,
    required this.pulse,
    required this.locked,
  });

  final Color color;
  final double pulse;
  final bool locked;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.36);
    final base = size.width * (locked ? 0.5 : 0.62);
    final r = locked
        ? base
        : base + math.sin(pulse * math.pi * 2) * size.width * 0.05;
    final paint = Paint()
      ..color = color.withValues(alpha: locked ? 1 : 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = locked ? 3 : 2.2
      ..strokeCap = StrokeCap.round;

    const segments = 4;
    final rotation = locked ? 0.0 : pulse * math.pi / 2;
    for (var i = 0; i < segments; i++) {
      final start = rotation + i * math.pi / 2 + 0.25;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        start,
        math.pi / 2 - 0.5,
        false,
        paint,
      );
    }
    final tick = size.width * 0.12;
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        center + dir * (r - tick * 0.5),
        center + dir * (r + tick),
        paint,
      );
    }
    if (locked) {
      canvas.drawCircle(center, 3, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_CrosshairPainter old) =>
      old.pulse != pulse || old.locked != locked || old.color != color;
}

/// Small static balloon for HUD rows.
class MiniBalloon extends StatelessWidget {
  const MiniBalloon({
    super.key,
    required this.color,
    this.standing = true,
    this.size = 14,
  });

  final Color color;
  final bool standing;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: standing ? 1 : 0.25,
      child: CustomPaint(
        size: Size(size, size * 1.45),
        painter: BalloonPainter(
          color: standing ? color : Colors.grey,
          destroyed: false,
        ),
      ),
    );
  }
}
