import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../app/theme.dart';
import '../models/game_config.dart';
import '../models/game_result.dart';
import '../models/game_state.dart';
import '../rendering/paper_painter.dart';
import '../widgets/animated_count.dart';
import '../widgets/celebration.dart';
import '../widgets/ink_button.dart';
import 'game_screen.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.result, required this.config});

  final GameResult result;

  /// Used to start a rematch with the same settings.
  final GameConfig config;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Animation<double> _at(
    double begin,
    double end, [
    Curve curve = Curves.easeOutCubic,
  ]) => CurvedAnimation(
    parent: _intro,
    curve: Interval(begin, end, curve: curve),
  );

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final winner = r.winnerLine;
    final humanWon = winner != null && !winner.isBot;
    final (title, color) = switch (winner) {
      null => ('DRAW', AppColors.inkSoft),
      final w when w.isBot => ('DEFEAT', AppColors.inkSoft),
      final w => ('VICTORY!', w.color),
    };

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: PaperPainter(seed: 21)),
          ),
          if (humanWon)
            Positioned.fill(
              child: Celebration(
                colors: [winner.color, AppColors.gold, AppColors.ink],
              ),
            ),
          if (winner == null)
            Positioned.fill(
              child: Celebration(
                colors: [r.bottom.color, r.top.color],
                count: 30,
              ),
            ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.lg,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: [
                      _Title(
                        title: title,
                        color: color,
                        animation: _at(0, 0.45, Curves.easeOutBack),
                        defeat: winner?.isBot ?? false,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      FadeTransition(
                        opacity: _at(0.3, 0.6),
                        child: Column(
                          children: [
                            Text(
                              r.trigger.headline.toUpperCase(),
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              r.outcome.reason.description,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 0.15),
                          end: Offset.zero,
                        ).animate(_at(0.35, 0.8)),
                        child: FadeTransition(
                          opacity: _at(0.35, 0.75),
                          child: _ComparisonTable(result: r),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      FadeTransition(
                        opacity: _at(0.6, 1),
                        child: Column(
                          children: [
                            InkButton(
                              label: 'PLAY AGAIN',
                              icon: Icons.replay_rounded,
                              primary: true,
                              onPressed: () => Navigator.of(context)
                                  .pushReplacement(
                                    inkRoute(GameScreen(config: widget.config)),
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            InkButton(
                              label: 'HOME',
                              icon: Icons.home_rounded,
                              onPressed: () => Navigator.of(context)
                                  .pushNamedAndRemoveUntil(
                                    AppRoutes.home,
                                    (route) => false,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({
    required this.title,
    required this.color,
    required this.animation,
    required this.defeat,
  });

  final String title;
  final Color color;
  final Animation<double> animation;
  final bool defeat;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        // Victory/draw pop in; defeat drops and settles slightly askew.
        final dy = defeat ? (1 - t.clamp(0.0, 1.0)) * -40 : 0.0;
        final angle = defeat ? -0.05 * t.clamp(0.0, 1.0) : 0.0;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Transform.rotate(
              angle: angle,
              child: Transform.scale(
                scale: defeat ? 1 : 0.6 + 0.4 * t,
                child: child,
              ),
            ),
          ),
        );
      },
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 56,
          fontWeight: FontWeight.w900,
          letterSpacing: 3,
          color: color,
          shadows: const [Shadow(color: AppColors.ink, offset: Offset(0, 4))],
        ),
      ),
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({required this.result});

  final GameResult result;

  @override
  Widget build(BuildContext context) {
    final a = result.bottom;
    final b = result.top;
    final reason = result.outcome.reason;
    final rows = <_Row>[
      _Row(
        'Balloons destroyed',
        a.balloonsDestroyed,
        b.balloonsDestroyed,
        decisive:
            reason == WinReason.allBalloonsDestroyed ||
            reason == WinReason.moreBalloonsDestroyed,
      ),
      _Row(
        'Total score',
        a.score,
        b.score,
        decisive: reason == WinReason.higherScore,
      ),
      _Row(
        'Distance',
        a.distance,
        b.distance,
        decisive: reason == WinReason.longerDistance,
      ),
      _Row('Crossings', a.successfulRuns, b.successfulRuns),
      _Row('Obstacle penalties', a.penalties, b.penalties, lowerIsBetter: true),
      _Row('Failed runs', a.failedRuns, b.failedRuns, lowerIsBetter: true),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.ink, width: 2),
        boxShadow: const [
          BoxShadow(color: AppColors.ink, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Spacer(),
              _Header(name: a.name, color: a.color),
              const SizedBox(width: 12),
              _Header(name: b.name, color: b.color),
            ],
          ),
          const SizedBox(height: 6),
          for (final row in rows) _RowView(row: row, a: a, b: b),
          const SizedBox(height: 4),
          Text(
            '${result.rounds} round${result.rounds == 1 ? '' : 's'} played',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _Row {
  const _Row(
    this.label,
    this.a,
    this.b, {
    this.decisive = false,
    this.lowerIsBetter = false,
  });

  final String label;
  final int a;
  final int b;
  final bool decisive;
  final bool lowerIsBetter;

  /// 0 if the bottom player leads, 1 if the top player does, null if tied.
  int? get leader {
    if (a == b) return null;
    final aBetter = lowerIsBetter ? a < b : a > b;
    return aBetter ? 0 : 1;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Text(
        name,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          color: color,
        ),
      ),
    );
  }
}

class _RowView extends StatelessWidget {
  const _RowView({required this.row, required this.a, required this.b});

  final _Row row;
  final ResultLine a;
  final ResultLine b;

  @override
  Widget build(BuildContext context) {
    Widget cell(int value, int index, Color color) {
      final leads = row.leader == index;
      return SizedBox(
        width: 64,
        child: Text(
          formatThousands(value),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: row.decisive ? 18 : 15,
            fontWeight: leads ? FontWeight.w900 : FontWeight.w600,
            color: leads ? color : AppColors.inkSoft,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: row.decisive ? AppColors.gold.withValues(alpha: 0.18) : null,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: row.decisive
            ? Border.all(color: AppColors.gold, width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          if (row.decisive) ...[
            const Icon(Icons.star_rounded, size: 16, color: AppColors.gold),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              row.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: row.decisive ? FontWeight.w800 : FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          cell(row.a, 0, a.color),
          const SizedBox(width: 12),
          cell(row.b, 1, b.color),
        ],
      ),
    );
  }
}
