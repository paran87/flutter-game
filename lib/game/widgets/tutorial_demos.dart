import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../models/balloon.dart';
import 'balloon_widget.dart';
import 'player_marker.dart';

/// Hosts a looping animated demo painter.
class LoopingDemo extends StatefulWidget {
  const LoopingDemo({
    super.key,
    required this.painter,
    this.duration = const Duration(seconds: 3),
  });

  final CustomPainter Function(Animation<double> t) painter;
  final Duration duration;

  @override
  State<LoopingDemo> createState() => _LoopingDemoState();
}

class _LoopingDemoState extends State<LoopingDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: widget.painter(_c), size: Size.infinite);
}

// Shared helpers ---------------------------------------------------------

void _paintDots(
  Canvas canvas,
  Size size,
  int seed, {
  int count = 40,
  Rect? avoid,
}) {
  final rng = math.Random(seed);
  final paint = Paint();
  for (var i = 0; i < count; i++) {
    final p = Offset(
      rng.nextDouble() * size.width,
      size.height * (0.18 + rng.nextDouble() * 0.64),
    );
    if (avoid != null && avoid.contains(p)) continue;
    final light = rng.nextDouble() < 0.25;
    paint.color = (light ? AppColors.inkSoft : AppColors.ink).withValues(
      alpha: light ? 0.3 : 0.85,
    );
    canvas.drawCircle(p, 1.5 + math.pow(rng.nextDouble(), 2) * 5, paint);
  }
}

/// Draws [path] up to fraction [t] as a ballpoint stroke.
void _paintInk(Canvas canvas, Path path, double t, Color color) {
  final metrics = path.computeMetrics().toList();
  final total = metrics.fold<double>(0, (a, m) => a + m.length);
  var remaining = total * t.clamp(0.0, 1.0);
  for (final m in metrics) {
    final part = m.extractPath(0, math.min(remaining, m.length));
    canvas.drawPath(
      part,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = Color.lerp(AppColors.paper, color, 0.75)!,
    );
    canvas.drawPath(
      part,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
    remaining -= m.length;
    if (remaining <= 0) break;
  }
}

Offset _pointAt(Path path, double t) {
  final m = path.computeMetrics().first;
  return m.getTangentForOffset(m.length * t.clamp(0.0, 1.0))!.position;
}

void _label(
  Canvas canvas,
  String text,
  Offset center,
  Color color, {
  double size = 14,
  double opacity = 1,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color.withValues(alpha: opacity),
        fontSize: size,
        fontWeight: FontWeight.w900,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
}

// 1. Drag ------------------------------------------------------------------

/// Finger below, pen above, ink trailing behind the pen.
class DragDemoPainter extends CustomPainter {
  DragDemoPainter(this.t) : super(repaint: t);

  final Animation<double> t;

  @override
  void paint(Canvas canvas, Size size) {
    _paintDots(
      canvas,
      size,
      3,
      count: 26,
      avoid: Rect.fromLTWH(size.width * 0.3, 0, size.width * 0.4, size.height),
    );
    final route = Path()
      ..moveTo(size.width * 0.5, size.height * 0.9)
      ..cubicTo(
        size.width * 0.35,
        size.height * 0.65,
        size.width * 0.65,
        size.height * 0.45,
        size.width * 0.48,
        size.height * 0.12,
      );
    final p = Curves.easeInOut.transform((t.value * 1.25).clamp(0.0, 1.0));
    _paintInk(canvas, route, p, AppColors.p1);
    final pen = _pointAt(route, p);
    final finger = pen + const Offset(0, 46);

    // Tether + finger.
    final tether = Paint()..color = AppColors.p1.withValues(alpha: 0.35);
    for (var d = 8.0; d < 40; d += 6) {
      canvas.drawCircle(pen + Offset(0, d), 1.2, tether);
    }
    canvas.drawCircle(
      finger,
      16,
      Paint()..color = AppColors.inkSoft.withValues(alpha: 0.18),
    );
    canvas.drawCircle(
      finger,
      16,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.inkSoft.withValues(alpha: 0.5),
    );
    PlayerMarkerPainter.paint(canvas, pen, 6, AppColors.p1);
  }

  @override
  bool shouldRepaint(DragDemoPainter old) => false;
}

// 2. Dots cost points ----------------------------------------------------

class DotsDemoPainter extends CustomPainter {
  DotsDemoPainter(this.t) : super(repaint: t);

  final Animation<double> t;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * 0.42;
    final dots = [
      (Offset(size.width * 0.2, y), 4.0, '-5'),
      (Offset(size.width * 0.5, y), 7.0, '-10'),
      (Offset(size.width * 0.8, y), 11.0, '-20'),
    ];
    // Which dot the pen passes through this loop.
    final active = (t.value * 3).floor() % 3;
    final local = (t.value * 3) % 1;
    for (var i = 0; i < dots.length; i++) {
      final (c, r, text) = dots[i];
      final hit = i == active && local > 0.45 && local < 0.8;
      canvas.drawCircle(
        c,
        r,
        Paint()..color = hit ? AppColors.p1 : AppColors.ink,
      );
      _label(canvas, text, c + Offset(0, r + 26), AppColors.penalty, size: 13);
    }
    final (c, r, text) = dots[active];
    final route = Path()
      ..moveTo(c.dx - 6, size.height * 0.95)
      ..quadraticBezierTo(c.dx + 10, c.dy + 30, c.dx, c.dy - 50);
    _paintInk(canvas, route, local, AppColors.p1);
    PlayerMarkerPainter.paint(canvas, _pointAt(route, local), 5, AppColors.p1);
    if (local > 0.45) {
      final rise = (local - 0.45) / 0.55;
      _label(
        canvas,
        text,
        c - Offset(0, r + 14 + 24 * rise),
        AppColors.penalty,
        size: 18,
        opacity: 1 - rise,
      );
    }
  }

  @override
  bool shouldRepaint(DotsDemoPainter old) => false;
}

// 3. Reach the other side, mind the ink ---------------------------------

class CrossDemoPainter extends CustomPainter {
  CrossDemoPainter(this.t) : super(repaint: t);

  final Animation<double> t;

  @override
  void paint(Canvas canvas, Size size) {
    final goalY = size.height * 0.16;
    final dash = Paint()
      ..color = AppColors.p1.withValues(alpha: 0.6)
      ..strokeWidth = 2;
    for (var x = 12.0; x < size.width - 12; x += 14) {
      canvas.drawLine(Offset(x, goalY), Offset(x + 8, goalY), dash);
    }
    _paintDots(canvas, size, 9, count: 30);
    final route = Path()
      ..moveTo(size.width * 0.5, size.height * 0.92)
      ..cubicTo(
        size.width * 0.2,
        size.height * 0.7,
        size.width * 0.85,
        size.height * 0.45,
        size.width * 0.55,
        goalY - 4,
      );
    final p = (t.value * 1.4).clamp(0.0, 1.0);
    _paintInk(canvas, route, p, AppColors.p1);
    PlayerMarkerPainter.paint(canvas, _pointAt(route, p), 6, AppColors.p1);

    // Ink meter draining as the line grows.
    final bar = Rect.fromLTWH(
      size.width * 0.08,
      size.height * 0.9,
      size.width * 0.3,
      7,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bar, const Radius.circular(4)),
      Paint()..color = AppColors.paperShade,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          bar.left,
          bar.top,
          bar.width * (1 - 0.55 * p),
          bar.height,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = AppColors.p1,
    );
    if (p >= 1) {
      final k = ((t.value * 1.4) - 1) / 0.4;
      canvas.drawCircle(
        _pointAt(route, 1),
        10 + 30 * k,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - k) + 0.5
          ..color = AppColors.p1.withValues(alpha: 1 - k),
      );
      _label(
        canvas,
        '+790',
        Offset(size.width * 0.78, goalY + 26),
        AppColors.success,
        size: 17,
        opacity: 1 - k * 0.5,
      );
    }
  }

  @override
  bool shouldRepaint(CrossDemoPainter old) => false;
}

// 4. Pop a balloon --------------------------------------------------------

/// Three opponent balloons; one gets targeted and popped, then they reset.
class BalloonDemo extends StatefulWidget {
  const BalloonDemo({super.key});

  @override
  State<BalloonDemo> createState() => _BalloonDemoState();
}

/// The pen crosses the dashed line, keeps going, runs into the middle
/// balloon and pops it. Loops.
class _BalloonDemoState extends State<BalloonDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..repeat();

  static const _hitAt = 0.62;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        const balloonWidth = 46.0;
        final balloonY = size.height * 0.24;
        return AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            final crossed = t > 0.42;
            final status = t < _hitAt
                ? BalloonStatus.intact
                : t < _hitAt + 0.22
                ? BalloonStatus.popping
                : BalloonStatus.destroyed;
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _HuntPainter(
                      t / _hitAt,
                      balloonY,
                      popped: t >= _hitAt,
                    ),
                  ),
                ),
                for (var i = 0; i < 3; i++)
                  Positioned(
                    left: size.width * (0.2 + 0.3 * i) - balloonWidth / 2,
                    top: balloonY - balloonWidth * 1.45 * 0.36,
                    child: BalloonWidget(
                      color: AppColors.p2,
                      status: i == 1 ? status : BalloonStatus.intact,
                      width: balloonWidth,
                      index: i,
                      aimed:
                          crossed && (i != 1 || status == BalloonStatus.intact),
                      attackerColor: AppColors.p1,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _HuntPainter extends CustomPainter {
  _HuntPainter(this.progress, this.balloonY, {required this.popped});

  final double progress;
  final double balloonY;
  final bool popped;

  @override
  void paint(Canvas canvas, Size size) {
    final lineY = size.height * 0.5;
    final dash = Paint()
      ..color = AppColors.p1.withValues(alpha: 0.6)
      ..strokeWidth = 2;
    for (var x = 12.0; x < size.width - 12; x += 14) {
      canvas.drawLine(Offset(x, lineY), Offset(x + 8, lineY), dash);
    }
    _paintDots(
      canvas,
      size,
      21,
      count: 18,
      avoid: Rect.fromLTWH(0, 0, size.width, lineY + 6),
    );
    final route = Path()
      ..moveTo(size.width * 0.35, size.height * 0.98)
      ..cubicTo(
        size.width * 0.15,
        size.height * 0.75,
        size.width * 0.7,
        size.height * 0.6,
        size.width * 0.5,
        balloonY,
      );
    final p = progress.clamp(0.0, 1.0);
    _paintInk(canvas, route, p, AppColors.p1);
    if (!popped) {
      PlayerMarkerPainter.paint(canvas, _pointAt(route, p), 5, AppColors.p1);
    } else {
      _label(
        canvas,
        '+790',
        Offset(size.width * 0.5, balloonY - 34),
        AppColors.p1,
        size: 16,
      );
    }
  }

  @override
  bool shouldRepaint(_HuntPainter old) =>
      old.progress != progress || old.popped != popped;
}

// 5. How to win ----------------------------------------------------------

class WinDemo extends StatelessWidget {
  const WinDemo({super.key});

  @override
  Widget build(BuildContext context) {
    Widget step(IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          step(Icons.emoji_events_rounded, 'Pop all 3 balloons: instant win'),
          const Divider(),
          const Text(
            "Time's up? The tie-breakers:",
            style: TextStyle(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 4),
          step(Icons.looks_one_rounded, 'More balloons destroyed'),
          step(Icons.looks_two_rounded, 'Higher total score'),
          step(Icons.looks_3_rounded, 'Longer total distance'),
        ],
      ),
    );
  }
}
