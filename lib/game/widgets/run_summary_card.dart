import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../models/game_stats.dart';
import '../models/player.dart';
import 'animated_count.dart';

/// "RUN COMPLETE!" receipt: distance, obstacle penalties and run score,
/// counted up line by line.
class RunSummaryCard extends StatefulWidget {
  const RunSummaryCard({
    super.key,
    required this.player,
    required this.summary,
  });

  final Player player;
  final RunSummary summary;

  @override
  State<RunSummaryCard> createState() => _RunSummaryCardState();
}

class _RunSummaryCardState extends State<RunSummaryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..forward();

  Animation<double> _interval(
    double begin,
    double end, [
    Curve curve = Curves.easeOutCubic,
  ]) => CurvedAnimation(
    parent: _c,
    curve: Interval(begin, end, curve: curve),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final identity = widget.player.identity;
    final s = widget.summary;
    final title = identity.isBot
        ? '${identity.name} CROSSED!'
        : 'RUN COMPLETE!';
    final pop = _interval(0, 0.3, Curves.easeOutBack);

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Transform.scale(
          scale: 0.7 + 0.3 * pop.value,
          child: Opacity(
            opacity: _interval(0, 0.15).value,
            child: Container(
              width: 260,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.ink, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.9),
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: identity.color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _line(
                    'Distance',
                    '+',
                    s.distancePoints,
                    AppColors.ink,
                    _interval(0.2, 0.55),
                  ),
                  const SizedBox(height: 6),
                  _line(
                    'Obstacles',
                    '-',
                    s.penalties,
                    AppColors.penalty,
                    _interval(0.35, 0.7),
                  ),
                  const SizedBox(height: 8),
                  _dashedRule(),
                  const SizedBox(height: 8),
                  _line(
                    'Run score',
                    '+',
                    s.runScore,
                    identity.color,
                    _interval(0.55, 0.95),
                    big: true,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _line(
    String label,
    String sign,
    int value,
    Color color,
    Animation<double> progress, {
    bool big = false,
  }) {
    final shown = (value * progress.value).round();
    return Opacity(
      opacity: progress.value.clamp(0.0, 1.0),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: big ? 16 : 14,
              fontWeight: big ? FontWeight.w900 : FontWeight.w600,
              color: AppColors.inkSoft,
            ),
          ),
          const Spacer(),
          Text(
            '$sign${formatThousands(shown)}',
            style: TextStyle(
              fontSize: big ? 24 : 17,
              fontWeight: FontWeight.w900,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashedRule() => Row(
    children: List.generate(
      22,
      (i) => Expanded(
        child: Container(
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          color: i.isEven ? AppColors.inkFaint : Colors.transparent,
        ),
      ),
    ),
  );
}
