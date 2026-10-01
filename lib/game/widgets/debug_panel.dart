import 'package:flutter/material.dart';

import '../controllers/game_controller.dart';
import '../models/player.dart';

/// Live numbers for tuning and bug hunting. Refreshes ~10× per second.
class DebugPanel extends StatefulWidget {
  const DebugPanel({super.key, required this.controller});

  final GameController controller;

  @override
  State<DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends State<DebugPanel> {
  int _frames = 0;
  double _lastTime = 0;
  double _fps = 0;
  final Map<Player, int> _lastPenalty = {};
  final Map<Player, int> _penaltySeen = {};

  @override
  void initState() {
    super.initState();
    widget.controller.frame.addListener(_onFrame);
  }

  @override
  void dispose() {
    widget.controller.frame.removeListener(_onFrame);
    super.dispose();
  }

  void _onFrame() {
    final c = widget.controller;
    for (final p in c.players) {
      final total = p.stats.totalPenalties;
      final seen = _penaltySeen[p] ?? 0;
      if (total > seen) _lastPenalty[p] = total - seen;
      _penaltySeen[p] = total;
    }
    _frames++;
    final elapsed = c.time - _lastTime;
    if (elapsed >= 0.1) {
      _fps = _frames / elapsed;
      _frames = 0;
      _lastTime = c.time;
      setState(() {});
    }
  }

  String _player(Player p) {
    final c = widget.controller;
    final collisions = c.collisionsFor(p);
    return '${p.identity.tag} ${p.identity.name}  ${p.runStatus.name}\n'
        '  pos (${p.position.dx.toStringAsFixed(1)}, ${p.position.dy.toStringAsFixed(1)})\n'
        '  run dist ${p.run.distance.toStringAsFixed(1)}  total ${(p.stats.totalDistance + p.run.distance).toStringAsFixed(1)}\n'
        '  score ${c.scoring.liveScore(p)}  run pen ${p.run.penalties}  total pen ${p.stats.totalPenalties}\n'
        '  touching ${collisions.isTouching ? collisions.touching.length : 0}  last -${_lastPenalty[p] ?? 0}  ink ${(c.inkFraction(p) * 100).round()}%\n'
        '  attempts ${p.attemptsRemaining}  balloons ${p.balloonsStanding}  popped ${p.stats.balloonsDestroyed}  hunting ${p.hasCrossed}\n'
        '  trace pts ${p.trace.points.length}  plan pts ${c.agentFor(p).debugPath.length}';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'phase ${c.phase.value.name}  '
          'timer ${c.timer.remaining.toStringAsFixed(1)}s  sim ${_fps.toStringAsFixed(0)} fps\n'
          'seed ${c.field.value.seed}  dots ${c.field.value.dots.length}\n'
          '${_player(c.bottom)}\n${_player(c.top)}',
          style: const TextStyle(
            color: Color(0xFF7CFFB2),
            fontSize: 9.5,
            height: 1.25,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}
