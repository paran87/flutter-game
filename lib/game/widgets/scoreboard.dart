import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../models/player.dart';
import 'animated_count.dart';
import 'attempts_widget.dart';
import 'balloon_widget.dart';
import 'ink_meter.dart';

/// Compact player card: name, score, attempts, balloons, distance and ink.
///
/// Rebuilds only when the player's [PlayerHudSnapshot] changes. Adapts to
/// the available width: below [_compactWidth] the name is dropped and
/// numbers scale down rather than overflow.
class PlayerScoreCard extends StatelessWidget {
  const PlayerScoreCard({
    super.key,
    required this.player,
    this.highlight = false,
  });

  final Player player;

  /// Emphasise the card (e.g. this player is attacking).
  final bool highlight;

  static const _compactWidth = 150.0;

  @override
  Widget build(BuildContext context) {
    final identity = player.identity;
    final labelStyle = Theme.of(context).textTheme.labelSmall
        ?.copyWith(fontSize: 9);
    return ValueListenableBuilder<PlayerHudSnapshot>(
      valueListenable: player.hud,
      builder: (context, hud, _) {
        final out = hud.attempts == 0;
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: out ? 0.55 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
            decoration: BoxDecoration(
              color: highlight ? identity.lightColor : AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: identity.color.withValues(alpha: highlight ? 0.9 : 0.35),
                width: highlight ? 2 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.07),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < _compactWidth - 18;
                final balloons = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < player.balloons.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(left: 1),
                        child: MiniBalloon(
                          color: identity.color,
                          standing: i < hud.balloonsStanding,
                          size: compact ? 8 : 9,
                        ),
                      ),
                  ],
                );
                final score = FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      AnimatedCount(
                        value: hud.score,
                        gainColor: AppColors.success,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text('PTS', style: labelStyle),
                    ],
                  ),
                );
                final distance = FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        formatThousands(hud.totalDistance),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.inkSoft,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text('DIST', style: labelStyle),
                    ],
                  ),
                );

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _Tag(identity: identity),
                        const SizedBox(width: 5),
                        if (!compact)
                          Expanded(
                            child: Text(
                              identity.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        // Hearts shrink rather than overflow on tiny cards.
                        Flexible(
                          flex: compact ? 1 : 0,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: AttemptsWidget(
                                remaining: hud.attempts,
                                max: hud.maxAttempts,
                                color: identity.color,
                                size: compact ? 10 : 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    if (compact) ...[
                      score,
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          balloons,
                          const SizedBox(width: 4),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: distance,
                            ),
                          ),
                        ],
                      ),
                    ] else
                      Row(
                        children: [
                          Expanded(child: score),
                          balloons,
                        ],
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: InkMeter(
                            percent: hud.inkPercent,
                            color: identity.color,
                            compact: true,
                            width: double.infinity,
                          ),
                        ),
                        if (!compact) ...[
                          const SizedBox(width: 6),
                          Flexible(child: distance),
                        ],
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.identity});

  final PlayerIdentity identity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: identity.color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        identity.tag,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
