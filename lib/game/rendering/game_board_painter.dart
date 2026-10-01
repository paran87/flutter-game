import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../../app/theme.dart';

import '../controllers/game_controller.dart';
import '../controllers/player_agent.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../widgets/player_marker.dart';
import 'board_transform.dart';
import 'debug_painter.dart';
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
    this.debug,
  }) : super(repaint: controller.frame);

  final GameController controller;
  final BoardTransform transform;
  final TraceRenderer traces;
  final EffectsPainter effects;

  /// Non-null when the debug overlay is enabled.
  final DebugPainter? debug;
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
    debug?.paint(canvas, controller);
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
    final config = controller.config;
    final center = transform.toScreen(player.position);
    final radius = config.playerRadius * transform.scale;
    var opacity = 1.0;
    var dim = false;
    switch (player.runStatus) {
      case RunStatus.failed:
        // Blink, then fade before reappearing at the start.
        final t =
            player.statusTime /
            (config.failureResetDuration.inMicroseconds / 1e6);
        final blink = (player.statusTime * 9).floor().isEven ? 1.0 : 0.35;
        opacity = blink * (1 - t).clamp(0.0, 1.0);
        dim = true;
      case RunStatus.eliminated:
        opacity = 0.45;
        dim = true;
      case RunStatus.ready:
      case RunStatus.running:
      case RunStatus.finished:
      case RunStatus.halted:
        break;
    }

    // Pen lifted mid-run: a ring drains as the grace period runs out.
    if (player.runStatus == RunStatus.running && player.penLiftedFor > 0) {
      final grace = config.penLiftGracePeriod.inMicroseconds / 1e6;
      final remaining = (1 - player.penLiftedFor / grace).clamp(0.0, 1.0);
      final ringRadius = radius * 3.4;
      canvas.drawCircle(
        center,
        ringRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = AppColors.danger.withValues(alpha: 0.15),
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: ringRadius),
        -math.pi / 2,
        math.pi * 2 * remaining,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = AppColors.danger,
      );
    }

    // A gentle "breathing" halo invites the player to start drawing.
    final idlePulse =
        player.runStatus == RunStatus.ready && controller.isPlaying
        ? (controller.time * 1.2) % 1.0
        : 0.0;

    // Name chips only while racing; they would clutter the attack screens.
    final phase = controller.phase.value;
    final showLabel =
        phase == GamePhase.intro ||
        phase == GamePhase.nextRound ||
        phase == GamePhase.countdown ||
        phase == GamePhase.playing;

    PlayerMarkerPainter.paint(
      canvas,
      center,
      radius,
      player.identity.color,
      label: showLabel ? player.identity.name : null,
      shake: player.shakeRemaining / 0.22,
      pulse: idlePulse,
      dim: dim,
      opacity: opacity,
    );
  }

  @override
  bool shouldRepaint(GameBoardPainter old) =>
      old.controller != controller || old.transform != transform;
}
