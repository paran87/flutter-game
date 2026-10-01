import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../models/game_config.dart';
import '../rendering/paper_painter.dart';
import '../services/settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = SettingsScope.of(context);
    final s = controller.value;
    return Scaffold(
      appBar: AppBar(title: const Text('SETTINGS')),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: PaperPainter(seed: 3)),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    _Section(
                      title: 'OPPONENT',
                      children: [
                        _Segmented<BotDifficulty>(
                          values: BotDifficulty.values,
                          selected: s.difficulty,
                          label: (d) => d.label,
                          onChanged: (d) => controller.update(
                            (s) => s.copyWith(difficulty: d),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _difficultyBlurb(s.difficulty),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    _Section(
                      title: 'MATCH LENGTH',
                      children: [
                        _Segmented<MatchLength>(
                          values: MatchLength.values,
                          selected: s.matchLength,
                          label: (m) => m.label,
                          onChanged: (m) => controller.update(
                            (s) => s.copyWith(matchLength: m),
                          ),
                        ),
                      ],
                    ),
                    _Section(
                      title: 'CONTROLS',
                      children: [
                        const _Label('Pen distance above your finger'),
                        _Segmented<TouchOffsetPreset>(
                          values: TouchOffsetPreset.values,
                          selected: s.touchOffset,
                          label: (o) => o.label,
                          onChanged: (o) => controller.update(
                            (s) => s.copyWith(touchOffset: o),
                          ),
                        ),
                        const SizedBox(height: 4),
                        _Toggle(
                          title: 'Pen-lift rule',
                          subtitle:
                              'Lifting your finger mid-run for more than '
                              '1.5 s fails the run.',
                          value: s.penLiftRule,
                          onChanged: (v) => controller.update(
                            (s) => s.copyWith(penLiftRule: v),
                          ),
                        ),
                      ],
                    ),
                    _Section(
                      title: 'FEEDBACK',
                      children: [
                        _Toggle(
                          title: 'Haptics',
                          subtitle: 'Light taps on collisions, stronger ones on pops.',
                          value: s.hapticsEnabled,
                          onChanged: (v) => controller.update(
                            (s) => s.copyWith(hapticsEnabled: v),
                          ),
                        ),
                        _Toggle(
                          title: 'Sound',
                          subtitle: 'Button clicks. Game sounds plug into the audio service.',
                          value: s.soundEnabled,
                          onChanged: (v) => controller.update(
                            (s) => s.copyWith(soundEnabled: v),
                          ),
                        ),
                      ],
                    ),
                    _Section(
                      title: 'DEVELOPER',
                      children: [
                        _Toggle(
                          title: 'Debug overlay',
                          subtitle: 'Coordinates, live stats, bot path and trace points.',
                          value: s.debugMode,
                          onChanged: (v) => controller.update(
                            (s) => s.copyWith(debugMode: v),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _difficultyBlurb(BotDifficulty d) => switch (d) {
    BotDifficulty.easy => 'Slow and wobbly. Wanders into dots often.',
    BotDifficulty.normal => 'Steady pace, picks reasonable routes.',
    BotDifficulty.hard => 'Fast and precise. Finds the gaps.',
  };
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.ink, width: 2),
        boxShadow: const [
          BoxShadow(color: AppColors.ink, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
  );
}

/// Pill-style segmented control with a sliding selection.
class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final index = values.indexOf(selected);
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.paperShade,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / values.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: width * index,
                width: width,
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final v in values)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: v == selected,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onChanged(v),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: v == selected
                                    ? AppColors.paper
                                    : AppColors.inkSoft,
                              ),
                              child: Text(label(v)),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
        // The whole row toggles, not just the small switch.
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}
