import 'package:flutter/material.dart';

import '../models/balloon.dart';
import '../models/game_config.dart';
import '../models/player.dart';
import '../rendering/board_decor_painter.dart';
import '../rendering/board_transform.dart';
import 'balloon_widget.dart';
import 'player_marker.dart';

/// The playing surface: decor, dots, traces, markers and balloons.
class GameBoard extends StatelessWidget {
  const GameBoard({
    super.key,
    required this.config,
    required this.bottom,
    required this.top,
    required this.onTransform,
  });

  final GameConfig config;
  final Player bottom;
  final Player top;

  /// Reports the current world→screen mapping (needed for touch input).
  final ValueChanged<BoardTransform> onTransform;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final transform = BoardTransform.fit(constraints.biggest, config);
        onTransform(transform);
        final balloonWidth = 92 * transform.scale;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: BoardDecorPainter(
                    config: config,
                    transform: transform,
                    topColor: top.identity.color,
                    bottomColor: bottom.identity.color,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _MockBoardPainter(transform, config, [bottom, top]),
              ),
            ),
            for (final player in [top, bottom])
              ..._balloons(player, transform, balloonWidth),
          ],
        );
      },
    );
  }

  Iterable<Widget> _balloons(
    Player player,
    BoardTransform transform,
    double width,
  ) sync* {
    final xs = config.balloonXs(player.balloons.length);
    final y = player.isTop ? config.topBalloonY : config.bottomBalloonY;
    for (final balloon in player.balloons) {
      final center = transform.toScreen(Offset(xs[balloon.index], y));
      final w = BalloonWidget(
        color: player.identity.color,
        status: balloon.status,
        width: width,
        index: balloon.index,
      );
      yield Positioned(
        left: center.dx - width / 2,
        top: center.dy - w.height * 0.4,
        child: w,
      );
    }
  }
}

/// Phase 1 placeholder: outlines the dot field and draws idle markers.
class _MockBoardPainter extends CustomPainter {
  _MockBoardPainter(this.transform, this.config, this.players);

  final BoardTransform transform;
  final GameConfig config;
  final List<Player> players;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(transform.origin.dx, transform.origin.dy);
    canvas.scale(transform.scale);
    canvas.drawRRect(
      RRect.fromRectAndRadius(config.fieldRect, const Radius.circular(24)),
      Paint()
        ..color = const Color(0x22000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.restore();
    // Markers are drawn in screen space so labels keep a readable size.
    for (final p in players) {
      PlayerMarkerPainter.paint(
        canvas,
        transform.toScreen(p.position),
        config.playerRadius * transform.scale,
        p.identity.color,
        label: p.identity.name,
      );
    }
  }

  @override
  bool shouldRepaint(_MockBoardPainter old) => true;
}

/// Mock balloon state helper for previews.
extension MockBalloons on Player {
  void mockPop(int index) => balloons[index].status = BalloonStatus.destroyed;
}
