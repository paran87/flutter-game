import 'package:flutter/rendering.dart';

import '../controllers/game_controller.dart';
import '../controllers/player_agent.dart';
import '../models/player.dart';
import '../widgets/player_marker.dart';
import 'board_transform.dart';
import 'effects_painter.dart';
import 'trace_painter.dart';

/// Dynamic board layer, repainted every frame from [GameController.frame]
/// without rebuilding any widgets.
class GameBoardPainter extends CustomPainter {
  GameBoardPainter({
    required this.controller,
    required this.transform,
    required this.traces,
    required this.effects,
    this.touchAgent,
  }) : super(repaint: controller.frame);

  final GameController controller;
  final BoardTransform transform;
  final TraceRenderer traces;
  final EffectsPainter effects;
  final TouchPlayerAgent? touchAgent;

  @override
  void paint(Canvas canvas, Size size) {
    _paintWorld(canvas);
    _paintTether(canvas);
    for (final player in controller.players) {
      _paintMarker(canvas, player);
    }
    effects.paintTexts(canvas, controller.effects, transform);
  }

  /// Everything drawn in world units: dot flashes, traces, bursts.
  void _paintWorld(Canvas canvas) {
    canvas.save();
    canvas.translate(transform.origin.dx, transform.origin.dy);
    canvas.scale(transform.scale);
    effects.paintWorldEffects(canvas, controller.effects);
    final live = <int>{};
    for (final f in controller.fadingTraces) {
      live.add(f.trace.id);
      traces.paint(canvas, f.trace, f.color, fade: f.progress);
    }
    for (final p in controller.players) {
      live.add(p.trace.id);
      traces.paint(canvas, p.trace, p.identity.color);
    }
    canvas.restore();
    traces.retainOnly(live);
  }

  /// A faint dotted "joystick" line from the finger to where the pen is
  /// heading, so the offset relationship is always readable.
  void _paintTether(Canvas canvas) {
    final agent = touchAgent;
    final finger = agent?.finger;
    final target = agent?.target;
    if (finger == null || target == null) return;
    final a = transform.toScreen(finger);
    final b = transform.toScreen(controller.bottom.position);
    final color = controller.bottom.identity.color;
    final paint = Paint()..color = color.withValues(alpha: 0.28);
    final length = (b - a).distance;
    if (length < 1) return;
    final dir = (b - a) / length;
    for (var d = 10.0; d < length - 10; d += 7) {
      canvas.drawCircle(a + dir * d, 1.3, paint);
    }
    // Finger ring.
    canvas.drawCircle(
      a,
      14,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = color.withValues(alpha: 0.25),
    );
    canvas.drawCircle(a, 3.5, paint);
  }

  void _paintMarker(Canvas canvas, Player player) {
    PlayerMarkerPainter.paint(
      canvas,
      transform.toScreen(player.position),
      controller.config.playerRadius * transform.scale,
      player.identity.color,
      label: player.identity.name,
      shake: player.shakeRemaining / 0.22,
    );
  }

  @override
  bool shouldRepaint(GameBoardPainter old) =>
      old.controller != controller || old.transform != transform;
}
